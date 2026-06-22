from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from typing import List
from datetime import datetime
import uuid

from ..database import get_db
from ..models import User, VerificationRequest
from ..dependencies import get_current_user
from ..s3_client import upload_file_to_s3, delete_file_from_s3  # 🆕 Импортируем S3

router = APIRouter(prefix="/verification", tags=["Verification"])

# 🆕 Подать заявку на верификацию
@router.post("/request")
async def create_verification_request(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Проверяем, что пользователь уже не верифицирован
    if current_user.is_verified:
        raise HTTPException(status_code=400, detail="Вы уже верифицированы")
    
    # Проверяем, нет ли уже активной заявки
    stmt = select(VerificationRequest).where(
        VerificationRequest.user_id == current_user.id,
        VerificationRequest.status == "pending"
    )
    result = await db.execute(stmt)
    existing_request = result.scalar_one_or_none()
    
    if existing_request:
        raise HTTPException(status_code=400, detail="У вас уже есть заявка на рассмотрении")
    
    # Проверяем, что это изображение
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Файл должен быть изображением")
    
    try:
        # 🆕 Загружаем файл в S3
        s3_url = await upload_file_to_s3(file, folder="verification")
        
        # Создаём заявку с S3 URL
        new_request = VerificationRequest(
            user_id=current_user.id,
            photo_url=s3_url,  # 🆕 Теперь храним полный S3 URL
            status="pending"
        )
        db.add(new_request)
        await db.commit()
        await db.refresh(new_request)
        
        return {
            "message": "Заявка на верификацию отправлена!",
            "request_id": str(new_request.id),
            "status": new_request.status
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ошибка загрузки фото: {str(e)}"
        )

# 🆕 Получить статус своей заявки
@router.get("/status")
async def get_verification_status(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Если уже верифицирован
    if current_user.is_verified:
        return {
            "is_verified": True,
            "status": "approved"
        }
    
    # Ищем последнюю заявку
    stmt = select(VerificationRequest).where(
        VerificationRequest.user_id == current_user.id
    ).order_by(VerificationRequest.created_at.desc()).limit(1)
    result = await db.execute(stmt)
    request = result.scalar_one_or_none()
    
    if not request:
        return {
            "is_verified": False,
            "status": None,
            "message": "Вы ещё не подавали заявку на верификацию"
        }
    
    return {
        "is_verified": False,
        "status": request.status,
        "request_id": str(request.id),
        "created_at": request.created_at.isoformat(),
        "admin_comment": request.admin_comment
    }

# 🆕 Получить все заявки на рассмотрении (для админа)
@router.get("/pending", response_model=List[dict])
async def get_pending_requests(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Проверяем, что пользователь — админ
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Только администраторы могут просматривать заявки")
    
    stmt = select(VerificationRequest, User).join(
        User, VerificationRequest.user_id == User.id
    ).where(
        VerificationRequest.status == "pending"
    ).order_by(VerificationRequest.created_at.asc())
    
    result = await db.execute(stmt)
    requests_data = result.all()
    
    pending_requests = []
    for request, user in requests_data:
        pending_requests.append({
            "request_id": str(request.id),
            "user_id": str(user.id),
            "username": user.username,
            "phone": user.phone,
            "photo_url": request.photo_url,
            "created_at": request.created_at.isoformat()
        })
    
    return pending_requests

# 🆕 Одобрить заявку (для админа)
@router.post("/{request_id}/approve")
async def approve_verification_request(
    request_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Проверяем, что пользователь — админ
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Только администраторы могут одобрять заявки")
    
    # Находим заявку
    request = await db.get(VerificationRequest, request_id)
    if not request:
        raise HTTPException(status_code=404, detail="Заявка не найдена")
    
    if request.status != "pending":
        raise HTTPException(status_code=400, detail="Заявка уже рассмотрена")
    
    # Обновляем заявку
    request.status = "approved"
    request.reviewed_at = datetime.utcnow()
    request.reviewed_by = current_user.id
    
    # Верифицируем пользователя
    user = await db.get(User, request.user_id)
    user.is_verified = True
    
    await db.commit()
    
    return {"message": "Заявка одобрена, пользователь верифицирован!"}

# 🆕 Отклонить заявку (для админа)
@router.post("/{request_id}/reject")
async def reject_verification_request(
    request_id: UUID,
    comment: str = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Проверяем, что пользователь — админ
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Только администраторы могут отклонять заявки")
    
    # Находим заявку
    request = await db.get(VerificationRequest, request_id)
    if not request:
        raise HTTPException(status_code=404, detail="Заявка не найдена")
    
    if request.status != "pending":
        raise HTTPException(status_code=400, detail="Заявка уже рассмотрена")
    
    # Обновляем заявку
    request.status = "rejected"
    request.reviewed_at = datetime.utcnow()
    request.reviewed_by = current_user.id
    request.admin_comment = comment
    
    await db.commit()
    
    return {"message": "Заявка отклонена"}