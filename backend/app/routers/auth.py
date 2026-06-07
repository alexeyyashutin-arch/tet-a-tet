import random
import logging
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from ..database import get_db
from ..models import User
from ..schemas import SendCodeRequest, VerifyCodeRequest, TokenResponse
from ..jwt_utils import create_access_token

router = APIRouter(prefix="/auth", tags=["Авторизация"])

# Настройки безопасности
OTP_EXPIRE_MINUTES = 5
SMS_COOLDOWN_SECONDS = 60
MAX_FAILED_ATTEMPTS = 5
BLOCK_DURATION_MINUTES = 15

@router.post("/send-code", status_code=status.HTTP_200_OK)
async def send_sms_code(data: SendCodeRequest, db: AsyncSession = Depends(get_db)):
    stmt = select(User).where(User.phone == data.phone)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        user = User(phone=data.phone)
        db.add(user)
        await db.flush()

    if user.blocked_until and user.blocked_until > datetime.now(timezone.utc):
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Слишком много попыток. Попробуйте позже.")

    if user.last_code_sent_at:
        time_since_last = datetime.now(timezone.utc) - user.last_code_sent_at
        if time_since_last.total_seconds() < SMS_COOLDOWN_SECONDS:
            wait_time = SMS_COOLDOWN_SECONDS - time_since_last.total_seconds()
            raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=f"Подождите {int(wait_time)} секунд перед новым запросом.")

    code = f"{random.randint(1000, 9999)}"
    user.otp_code = code
    user.otp_expires_at = datetime.now(timezone.utc) + timedelta(minutes=OTP_EXPIRE_MINUTES)
    user.last_code_sent_at = datetime.now(timezone.utc)
    user.failed_attempts = 0
    
    await db.commit()
    
    # Выводим код в консоль
    print(f"🔥 SMS-код для {data.phone}: {code}", flush=True)
    return {"message": "Код отправлен. Проверьте SMS."}

# ⚠️ ВОТ ЭТОГО ДЕКОРАТОРА И ФУНКЦИИ СКОРЕЕ ВСЕГО НЕ ХВАТАЛО!
@router.post("/verify-code", response_model=TokenResponse)
async def verify_sms_code(data: VerifyCodeRequest, db: AsyncSession = Depends(get_db)):
    stmt = select(User).where(User.phone == data.phone)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Пользователь не найден")

    if user.blocked_until and user.blocked_until > datetime.now(timezone.utc):
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Слишком много попыток. Попробуйте позже.")

    is_code_valid = (
        user.otp_code == data.code and 
        user.otp_expires_at and 
        user.otp_expires_at > datetime.now(timezone.utc)
    )

    if not is_code_valid:
        user.failed_attempts += 1
        if user.failed_attempts >= MAX_FAILED_ATTEMPTS:
            user.blocked_until = datetime.now(timezone.utc) + timedelta(minutes=BLOCK_DURATION_MINUTES)
            print(f"🚨 Блокировка номера {data.phone} за брутфорс!", flush=True)
        
        await db.commit()
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Неверный код или время его действия истекло")

    user.otp_code = None
    user.otp_expires_at = None
    user.failed_attempts = 0
    user.blocked_until = None
    await db.commit()

    access_token = create_access_token(data={"sub": str(user.id)})
    return TokenResponse(access_token=access_token)