from pydantic import BaseModel, Field, field_validator, computed_field
from uuid import UUID
from datetime import date, datetime
import re

# Схема для запроса кода
class SendCodeRequest(BaseModel):
    phone: str = Field(..., description="Номер телефона")

    @field_validator('phone')
    @classmethod
    def validate_phone(cls, v: str) -> str:
        clean_phone = re.sub(r'[\s\-\(\)]', '', v)
        if not re.match(r'^\+?[1-9]\d{1,14}$', clean_phone):
            raise ValueError('Неверный формат номера телефона')
        return clean_phone

# Схема для проверки кода
class VerifyCodeRequest(BaseModel):
    phone: str
    code: str = Field(..., min_length=4, max_length=4, description="4-значный код из SMS")

# Схема для ответа с токеном
class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

# Схема для получения полного профиля
class UserProfile(BaseModel):
    id: UUID
    phone: str
    is_verified: bool
    username: str | None = None
    birth_date: date | None = None
    gender: str | None = None
    bio: str | None = None
    avatar_url: str | None = None
    
    # Магия Pydantic v2! Автоматически считаем возраст
    @computed_field
    @property
    def age(self) -> int | None:
        if self.birth_date is None:
            return None
        today = date.today()
        age = today.year - self.birth_date.year - ((today.month, today.day) < (self.birth_date.month, self.birth_date.day))
        return age
    
    model_config = {"from_attributes": True}

# Схема для обновления профиля
class UserUpdate(BaseModel):
    username: str | None = Field(None, max_length=50)
    birth_date: date | None = None
    gender: str | None = None
    bio: str | None = Field(None, max_length=500)
    avatar_url: str | None = None

# Схемы для фото
class PhotoResponse(BaseModel):
    id: UUID
    url: str
    uploaded_at: datetime
    model_config = {"from_attributes": True}

class PhotoUploadResponse(BaseModel):
    id: UUID
    url: str
    album_type: str
    uploaded_at: datetime

# Схема для предоставления доступа
class GrantAccessRequest(BaseModel):
    user_id: UUID

class AccessUserInfo(BaseModel):
    id: UUID
    username: str | None = None
    avatar_url: str | None = None
    model_config = {"from_attributes": True}

# Схемы для встреч
class MeetingCreate(BaseModel):
    title: str = Field(..., min_length=5, max_length=200)
    description: str | None = None
    meeting_date: date
    meeting_time: str = Field(..., pattern=r"^\d{2}:\d{2}$")  # Формат "18:00"
    location: str | None = None
    partner_wishes: str | None = None
    finance: str = Field(default="self", pattern=r"^(self|split|partner|none)$")

class MeetingResponse(BaseModel):
    id: UUID
    user_id: UUID
    title: str
    description: str | None
    meeting_date: date
    meeting_time: str
    location: str | None
    partner_wishes: str | None
    finance: str
    status: str
    created_at: datetime
    creator_username: str | None = None
    creator_avatar_url: str | None = None
    creator_age: int | None = None
    
    model_config = {"from_attributes": True}