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

router = APIRouter(prefix="/users", tags=["Профиль"])

@router.get("/me", response_model=UserProfile)
async def get_my_profile(current_user: User = Depends(get_current_user)):
    """
    Получить информацию о себе.
    Работает только если прислан валидный JWT-токен!
    """
    return current_user

@router.put("/me", response_model=UserProfile)
async def update_my_profile(
    user_data: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Обновить свой профиль.
    """
    # Обновляем только те поля, которые пользователь реально прислал
    update_data = user_data.model_dump(exclude_unset=True)
    
    for field, value in update_data.items():
        setattr(current_user, field, value)
        
    await db.commit()
    await db.refresh(current_user)
    
    return current_user

@router.post("/me/avatar", response_model=UserProfile)
async def upload_avatar(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # 1. Проверяем, что это картинка
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Файл должен быть изображением")
    
    # 2. Генерируем уникальное имя файла (чтобы два Васи не перезаписали друг друга)
    ext = file.filename.split(".")[-1] if "." in file.filename else "jpg"
    filename = f"{uuid.uuid4()}.{ext}"
    filepath = f"uploads/{filename}"
    
    # 3. Сохраняем файл на диск
    with open(filepath, "wb") as buffer:
        buffer.write(await file.read())
    
    # 4. Обновляем ссылку в базе данных
    current_user.avatar_url = f"/uploads/{filename}"
    await db.commit()
    await db.refresh(current_user)
    
    return current_user

# 🆕 Получить публичный профиль пользователя и его фото по ID
@router.get("/{user_id}/public")
async def get_public_user_profile(
    user_id: UUID,
    db: AsyncSession = Depends(get_db)
):
    # 1. Ищем пользователя
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    
    # 2. Считаем возраст
    age = None
    if user.birth_date:
        today = date.today()
        age = today.year - user.birth_date.year - ((today.month, today.day) < (user.birth_date.month, user.birth_date.day))
    
    # 3. Собираем данные пользователя (без чувствительных данных, только публичные)
    user_data = {
        "id": str(user.id),
        "username": user.username,
        "age": age,
        "gender": user.gender,
        "bio": user.bio,
        "city": user.city,
        "avatar_url": user.avatar_url,
        # 🆕 Новые поля профиля для умного подбора
        "height": user.height,
        "weight": user.weight,
        "body_type": user.body_type,
        "alcohol_attitude": user.alcohol_attitude,
        "smoking_attitude": user.smoking_attitude,
        "marital_status": user.marital_status,
        "has_children": user.has_children,
    }
    
    # 4. Получаем все фотографии пользователя
        # 🆕 Показываем только публичные фото (приватные — только владельцу!)
    stmt = select(Photo).where(
        Photo.user_id == user_id,
        Photo.album_type == "public"  # 🛡️ Защита приватности
    ).order_by(Photo.id.asc())
    result = await db.execute(stmt)
    photos = result.scalars().all()
    
    photos_data = [{"id": str(p.id), "photo_url": p.url} for p in photos] # 🆕 Используем правильное имя поля
    
    # 5. Возвращаем красивый структурированный ответ
    return {
        "user": user_data,
        "photos": photos_data
    }

# 🆕 Сохранить FCM токен для Push-уведомлений
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

# 🆕 Установить фото как аватарку
@router.put("/avatar")
async def set_avatar(
    data: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    photo_id = data.get('photo_id')
    if not photo_id:
        raise HTTPException(status_code=400, detail="photo_id обязателен")
    
    # Находим фото
    stmt = select(Photo).where(Photo.id == photo_id, Photo.user_id == current_user.id)
    result = await db.execute(stmt)
    photo = result.scalar_one_or_none()
    
    if not photo:
        raise HTTPException(status_code=404, detail="Фото не найдено")
    
    # Обновляем аватарку
    current_user.avatar_url = photo.url
    await db.commit()
    
    return {"message": "Аватарка обновлена"}

# 🆕 Сохранить настройки уведомлений
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

# 🆕 Получить настройки уведомлений
@router.get("/notification-settings")
async def get_notification_settings(
    current_user: User = Depends(get_current_user),
):
    return {
        "notify_responses": current_user.notify_responses,
        "notify_messages": current_user.notify_messages
    }

# 🆕 Удалить аккаунт (анонимизация)
@router.delete("/me")
async def delete_account(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Анонимизация аккаунта: удаляем персональные данные,
    но оставляем встречи, сообщения и отклики.
    """
    print(f"🗑️ Начинаем анонимизацию аккаунта: {current_user.phone}")
    
    # 1. Удаляем все фото пользователя с диска
    stmt = select(Photo).where(Photo.user_id == current_user.id)
    result = await db.execute(stmt)
    photos = result.scalars().all()
    
    for photo in photos:
        # Удаляем файл с диска
        if photo.url and photo.url.startswith('/uploads/'):
            filepath = f"uploads/{photo.url.replace('/uploads/', '')}"
            if os.path.exists(filepath):
                try:
                    os.remove(filepath)
                    print(f"🗑️ Удалён файл: {filepath}")
                except Exception as e:
                    print(f"❌ Ошибка удаления файла {filepath}: {e}")
        await db.delete(photo)
    print(f"🗑️ Удалено фото: {len(photos)}")
    
    # 2. Удаляем все заявки на верификацию
    stmt = select(VerificationRequest).where(VerificationRequest.user_id == current_user.id)
    result = await db.execute(stmt)
    verification_requests = result.scalars().all()
    
    for req in verification_requests:
        # Удаляем фото верификации с диска
        if req.photo_url and req.photo_url.startswith('/uploads/'):
            filepath = f"uploads/{req.photo_url.replace('/uploads/', '')}"
            if os.path.exists(filepath):
                try:
                    os.remove(filepath)
                    print(f"🗑️ Удалён файл верификации: {filepath}")
                except Exception as e:
                    print(f"❌ Ошибка удаления файла {filepath}: {e}")
        await db.delete(req)
    print(f"🗑️ Удалено заявок на верификацию: {len(verification_requests)}")
    
    # 3. Удаляем доступы к альбомам
    stmt = select(AlbumAccess).where(
        (AlbumAccess.owner_id == current_user.id) | (AlbumAccess.granted_to_id == current_user.id)
    )
    result = await db.execute(stmt)
    accesses = result.scalars().all()
    for access in accesses:
        await db.delete(access)
    print(f"🗑️ Удалено доступов к альбомам: {len(accesses)}")
    
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
    
    print(f"✅ Аккаунт анонимизирован: {current_user.phone}")
    
    return {"message": "Аккаунт успешно удалён"}