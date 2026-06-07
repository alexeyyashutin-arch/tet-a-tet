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
    
    # Генерируем имя файла
    ext = file.filename.split(".")[-1] if "." in file.filename else "jpg"
    filename = f"{uuid.uuid4()}.{ext}"
    filepath = f"uploads/{filename}"
    
    # Сохраняем
    with open(filepath, "wb") as buffer:
        buffer.write(await file.read())
    
    # Создаём запись в БД
    photo = Photo(
        user_id=current_user.id,
        album_type=album_type,
        url=f"/uploads/{filename}"
    )
    db.add(photo)
    await db.commit()
    await db.refresh(photo)
    
    return photo

@router.get("/public/{user_id}", response_model=List[PhotoResponse])
async def get_public_photos(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Photo).where(
        Photo.user_id == user_id,
        Photo.album_type == "public"
    ).order_by(Photo.uploaded_at.desc())
    
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
    ).order_by(Photo.uploaded_at.desc())
    
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
    )
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
    
    # Удаляем файл с диска
    try:
        os.remove(photo.url.lstrip("/"))
    except:
        pass
    
    await db.delete(photo)
    await db.commit()
    
    return {"message": "Фото удалено"}