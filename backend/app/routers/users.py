import os
import uuid
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import date
from sqlalchemy import select
from ..database import get_db
from ..models import User, Photo, VerificationRequest, AlbumAccess
from ..schemas import UserProfile, UserUpdate
from ..dependencies import get_current_user
from ..redis_client import cache_get, cache_set, cache_delete  # 🆕 Redis
from ..s3_client import upload_file_to_s3, delete_file_from_s3  # 🆕 S3

router = APIRouter(prefix="/users", tags=["Профиль"])

@router.get("/me", response_model=UserProfile)
async def get_my_profile(current_user: User = Depends(get_current_user)):
    return current_user

@router.put("/me", response_model=UserProfile)
async def update_my_profile(
    user_data: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    update_data = user_data.model_dump(exclude_unset=True)
    
    for field, value in update_data.items():
        setattr(current_user, field, value)
        
    await db.commit()
    await db.refresh(current_user)
    
    # 🆕 Инвалидируем кэш профиля, чтобы другие увидели изменения
    await cache_delete(f"user:profile:{current_user.id}")
    
    return current_user

@router.post("/me/avatar", response_model=UserProfile)
async def upload_avatar(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Файл должен быть изображением")
    
    # 🆕 Загружаем аватарку в S3 (вместо локального диска)
    try:
        s3_url = await upload_file_to_s3(file, folder="avatars")
    except Exception as e:
        raise HTTPException(status_code=500, detail="Ошибка загрузки в облако")
    
    # 🆕 Удаляем старую аватарку из S3, если она была локальной или старой из облака
    if current_user.avatar_url:
        try:
            await delete_file_from_s3(current_user.avatar_url)
        except:
            pass

    current_user.avatar_url = s3_url
    await db.commit()
    await db.refresh(current_user)
    
    #  Инвалидируем кэш
    await cache_delete(f"user:profile:{current_user.id}")
    
    return current_user

# 🆕 Получить публичный профиль пользователя и его фото по ID (С КЭШИРОВАНИЕМ!)
@router.get("/{user_id}/public")
async def get_public_user_profile(
    user_id: UUID,
    db: AsyncSession = Depends(get_db)
):
    # 🆕 Формируем ключ кэша
    cache_key = f"user:profile:{user_id}"
    
    # 🆕 Проверяем кэш
    cached_data = await cache_get(cache_key)
    if cached_data:
        return cached_data
    
    # 1. Ищем пользователя
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    
    # 2. Считаем возраст
    age = None
    if user.birth_date:
        today = date.today()
        age = today.year - user.birth_date.year - ((today.month, today.day) < (user.birth_date.month, user.birth_date.day))
    
    # 3. Собираем данные
    user_data = {
        "id": str(user.id),
        "username": user.username,
        "age": age,
        "gender": user.gender,
        "bio": user.bio,
        "city": user.city,
        "avatar_url": user.avatar_url,
        "height": user.height,
        "weight": user.weight,
        "body_type": user.body_type,
        "alcohol_attitude": user.alcohol_attitude,
        "smoking_attitude": user.smoking_attitude,
        "marital_status": user.marital_status,
        "has_children": user.has_children,
    }
    
    # 4. Получаем публичные фото
    stmt = select(Photo).where(
        Photo.user_id == user_id,
        Photo.album_type == "public"
    ).order_by(Photo.id.asc())
    result = await db.execute(stmt)
    photos = result.scalars().all()
    
    photos_data = [{"id": str(p.id), "photo_url": p.url} for p in photos]
    
    response_data = {
        "user": user_data,
        "photos": photos_data
    }
    
    # 🆕 Сохраняем в кэш на 5 минут (300 секунд)
    await cache_set(cache_key, response_data, expire=300)
    
    return response_data

@router.put("/fcm-token")
async def update_fcm_token(
    token_data: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    fcm_token = token_data.get("fcm_token")
    if not fcm_token:
        raise HTTPException(status_code=400, detail="Токен обязателен")
    
    current_user.fcm_token = fcm_token
    await db.commit()
    
    return {"message": "FCM токен успешно сохранен"}

@router.put("/avatar")
async def set_avatar(
    data: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    photo_id = data.get('photo_id')
    if not photo_id:
        raise HTTPException(status_code=400, detail="photo_id обязателен")
    
    stmt = select(Photo).where(Photo.id == photo_id, Photo.user_id == current_user.id)
    result = await db.execute(stmt)
    photo = result.scalar_one_or_none()
    
    if not photo:
        raise HTTPException(status_code=404, detail="Фото не найдено")
    
    current_user.avatar_url = photo.url
    await db.commit()
    
    #  Инвалидируем кэш
    await cache_delete(f"user:profile:{current_user.id}")
    
    return {"message": "Аватарка обновлена"}

@router.put("/notification-settings")
async def update_notification_settings(
    settings: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    notify_responses = settings.get("notify_responses")
    notify_messages = settings.get("notify_messages")
    
    if notify_responses is not None:
        current_user.notify_responses = notify_responses
    if notify_messages is not None:
        current_user.notify_messages = notify_messages
    
    await db.commit()
    
    return {
        "message": "Настройки уведомлений обновлены",
        "notify_responses": current_user.notify_responses,
        "notify_messages": current_user.notify_messages
    }

@router.get("/notification-settings")
async def get_notification_settings(
    current_user: User = Depends(get_current_user),
):
    return {
        "notify_responses": current_user.notify_responses,
        "notify_messages": current_user.notify_messages
    }

@router.delete("/me")
async def delete_account(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    print(f"🗑️ Начинаем анонимизацию аккаунта: {current_user.phone}")
    
    # 1. Удаляем все фото пользователя из S3
    stmt = select(Photo).where(Photo.user_id == current_user.id)
    result = await db.execute(stmt)
    photos = result.scalars().all()
    
    for photo in photos:
        if photo.url:
            try:
                await delete_file_from_s3(photo.url) # 🆕 Удаляем из облака
            except Exception as e:
                print(f"❌ Ошибка удаления фото из S3: {e}")
        await db.delete(photo)
        
    # 2. Удаляем заявки на верификацию и их фото из S3
    stmt = select(VerificationRequest).where(VerificationRequest.user_id == current_user.id)
    result = await db.execute(stmt)
    verification_requests = result.scalars().all()
    
    for req in verification_requests:
        if req.photo_url:
            try:
                await delete_file_from_s3(req.photo_url) # 🆕 Удаляем из облака
            except Exception as e:
                print(f"❌ Ошибка удаления верификации из S3: {e}")
        await db.delete(req)
        
    # 3. Удаляем доступы к альбомам
    stmt = select(AlbumAccess).where(
        (AlbumAccess.owner_id == current_user.id) | (AlbumAccess.granted_to_id == current_user.id)
    )
    result = await db.execute(stmt)
    accesses = result.scalars().all()
    for access in accesses:
        await db.delete(access)
    
    # 4. Анонимизируем пользователя
    current_user.username = "Пользователь удалён"
    current_user.bio = None
    current_user.avatar_url = None
    current_user.birth_date = None
    current_user.gender = None
    current_user.city = None
    current_user.latitude = None
    current_user.longitude = None
    current_user.height = None
    current_user.weight = None
    current_user.body_type = None
    current_user.alcohol_attitude = None
    current_user.smoking_attitude = None
    current_user.marital_status = None
    current_user.has_children = None
    current_user.fcm_token = None
    current_user.is_verified = False
    
    await db.commit()
    
    # 🆕 Инвалидируем кэш профиля
    await cache_delete(f"user:profile:{current_user.id}")
    
    print(f"✅ Аккаунт анонимизирован: {current_user.phone}")
    
    return {"message": "Аккаунт успешно удалён"}