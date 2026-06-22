import os
import uuid
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List

from ..database import get_db
from ..models import User, Photo, AlbumAccess
from ..schemas import PhotoResponse, PhotoUploadResponse, GrantAccessRequest, AccessUserInfo
from ..dependencies import get_current_user
from ..s3_client import upload_file_to_s3, delete_file_from_s3  # 🆕 Импортируем S3

router = APIRouter(prefix="/photos", tags=["Фотографии"])

@router.post("/upload", response_model=PhotoUploadResponse)
async def upload_photo(
    file: UploadFile = File(...),
    album_type: str = Form("public"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Проверяем тип альбома
    if album_type not in ["public", "private"]:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Неверный тип альбома")
    
    # Проверяем файл
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Файл должен быть изображением")
    
    try:
        # 🆕 Загружаем файл в S3 вместо локального сохранения
        s3_url = await upload_file_to_s3(file, folder=f"albums/{album_type}")
        
        # Создаём запись в БД с S3 URL
        photo = Photo(
            user_id=current_user.id,
            album_type=album_type,
            url=s3_url  # 🆕 Теперь храним полный S3 URL
        )
        db.add(photo)
        await db.commit()
        await db.refresh(photo)
        
        return photo
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ошибка загрузки фото: {str(e)}"
        )

@router.get("/public/{user_id}", response_model=List[PhotoResponse])
async def get_public_photos(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Photo).where(
        Photo.user_id == user_id,
        Photo.album_type == "public"
    ).order_by(Photo.order_index.asc(), Photo.uploaded_at.asc())
    
    result = await db.execute(stmt)
    photos = result.scalars().all()
    return photos

@router.get("/private/my", response_model=List[PhotoResponse])
async def get_my_private_photos(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Photo).where(
        Photo.user_id == current_user.id,
        Photo.album_type == "private"
    ).order_by(Photo.order_index.asc(), Photo.uploaded_at.asc())
    
    result = await db.execute(stmt)
    photos = result.scalars().all()
    return photos

@router.get("/private/{user_id}", response_model=List[PhotoResponse])
async def get_user_private_photos(
    user_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Проверяем, есть ли доступ
    stmt = select(AlbumAccess).where(
        AlbumAccess.owner_id == user_id,
        AlbumAccess.granted_to_id == current_user.id
    ).order_by(Photo.order_index.asc(), Photo.uploaded_at.asc())
    result = await db.execute(stmt)
    access = result.scalar_one_or_none()
    
    if not access:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="У вас нет доступа к приватному альбому этого пользователя"
        )
    
    # Возвращаем фото
    stmt = select(Photo).where(
        Photo.user_id == user_id,
        Photo.album_type == "private"
    ).order_by(Photo.uploaded_at.desc())
    
    result = await db.execute(stmt)
    photos = result.scalars().all()
    return photos

@router.post("/private/grant-access")
async def grant_private_access(
    data: GrantAccessRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Проверяем, существует ли пользователь
    stmt = select(User).where(User.id == data.user_id)
    result = await db.execute(stmt)
    target_user = result.scalar_one_or_none()
    
    if not target_user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Пользователь не найден")
    
    # Проверяем, не выдан ли уже доступ
    stmt = select(AlbumAccess).where(
        AlbumAccess.owner_id == current_user.id,
        AlbumAccess.granted_to_id == data.user_id
    )
    result = await db.execute(stmt)
    existing = result.scalar_one_or_none()
    
    if existing:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Доступ уже предоставлен")
    
    # Выдаём доступ
    access = AlbumAccess(
        owner_id=current_user.id,
        granted_to_id=data.user_id
    )
    db.add(access)
    await db.commit()
    
    return {"message": "Доступ к приватному альбому предоставлен"}

@router.delete("/private/revoke-access/{user_id}")
async def revoke_private_access(
    user_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(AlbumAccess).where(
        AlbumAccess.owner_id == current_user.id,
        AlbumAccess.granted_to_id == user_id
    )
    result = await db.execute(stmt)
    access = result.scalar_one_or_none()
    
    if not access:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Доступ не найден")
    
    await db.delete(access)
    await db.commit()
    
    return {"message": "Доступ отозван"}

@router.get("/private/access-list", response_model=List[AccessUserInfo])
async def get_access_list(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Получаем список пользователей, которым дан доступ
    stmt = select(User).join(AlbumAccess, User.id == AlbumAccess.granted_to_id).where(
        AlbumAccess.owner_id == current_user.id
    )
    
    result = await db.execute(stmt)
    users = result.scalars().all()
    return users

@router.delete("/{photo_id}")
async def delete_photo(
    photo_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Photo).where(Photo.id == photo_id)
    result = await db.execute(stmt)
    photo = result.scalar_one_or_none()
    
    if not photo:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Фото не найдено")
    
    if photo.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Нельзя удалять чужие фото")
    
    # 🆕 Удаляем файл из S3
    try:
        await delete_file_from_s3(photo.url)
    except Exception as e:
        print(f"⚠️ Не удалось удалить файл из S3: {e}")
        # Продолжаем удаление из БД, даже если файл не удалился
    
    await db.delete(photo)
    await db.commit()
    
    return {"message": "Фото удалено"}


# 🆕 Изменить порядок фото и автоматически обновить аватарку, если нужно
@router.put("/reorder")
async def reorder_photos(
    data: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    album_type = data.get('album_type')
    photo_ids = data.get('photo_ids', [])
    
    if not album_type or not photo_ids:
        raise HTTPException(status_code=400, detail="album_type и photo_ids обязательны")
    
    # Обновляем порядок для каждого фото
    for index, photo_id in enumerate(photo_ids):
        stmt = select(Photo).where(Photo.id == photo_id, Photo.user_id == current_user.id)
        result = await db.execute(stmt)
        photo = result.scalar_one_or_none()
        
        if photo:
            photo.order_index = index
            
            # 🎯 МАГИЯ: Если это публичный альбом и фото встало на первое место (индекс 0)
            if album_type == 'public' and index == 0:
                current_user.avatar_url = photo.url
    
    # Сохраняем все изменения в базе данных
    await db.commit()
    
    return {"message": "Порядок обновлён, аватарка синхронизирована!"}