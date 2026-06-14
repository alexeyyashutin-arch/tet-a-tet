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

    # 🆕 Добавляем поля геолокации!
    city: str | None = None
    latitude: float | None = None
    longitude: float | None = None

    # 🆕 Новые поля профиля для умного подбора
    alcohol_attitude: str | None = None      # "Положительное", "Нейтральное", "Отрицательное"
    smoking_attitude: str | None = None      # "Категорически не приемлю", "Не курю, но не против", "Курю"
    
    height: int | None = None                # Рост в см
    weight: int | None = None                # Вес в кг
    body_type: str | None = None             # "Худощавое", "Обычное", "Спортивное", "Есть пара лишних кг", "Полное"
    
    marital_status: str | None = None        # "В браке", "Свободен"
    has_children: str | None = None          # "Есть", "Нет"

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
    city: str | None = None
    latitude: float | None = None
    longitude: float | None = None
 
    # 🆕 Новые поля профиля для умного подбора
    alcohol_attitude: str | None = None      # "Положительное", "Нейтральное", "Отрицательное"
    smoking_attitude: str | None = None      # "Категорически не приемлю", "Не курю, но не против", "Курю"
    
    height: int | None = None                # Рост в см
    weight: int | None = None                # Вес в кг
    body_type: str | None = None             # "Худощавое", "Обычное", "Спортивное", "Есть пара лишних кг", "Полное"
    
    marital_status: str | None = None        # "В браке", "Свободен"
    has_children: str | None = None          # "Есть", "Нет"

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
    meeting_time: str | None = None
    location: str | None = None
    partner_wishes: str | None = None
    finance: str = Field(default="self", pattern=r"^(self|split|partner|none)$")

class MeetingResponse(BaseModel):
    id: UUID
    user_id: UUID
    creator_id:UUID | None = None
    title: str
    description: str | None
    meeting_date: date
    meeting_time: str | None = None
    location: str | None
    partner_wishes: str | None
    finance: str
    status: str
    created_at: datetime
    creator_username: str | None = None
    creator_avatar_url: str | None = None
    creator_age: int | None = None
    creator_gender: str | None = None
    responses_count: int = 0  # 🆕 Добавляем поле для количества откликов (с дефолтом 0)
    has_responded: bool = False  # 🆕 Откликнулся ли текущий пользователь на эту встречу
   
    unread_responses_count: int = 0
   
    model_config = {"from_attributes": True}
    

# --- Схемы для откликов на встречи (Responses) ---

class MeetingResponseCreate(BaseModel):
    meeting_id: UUID
    response_message: str | None = None  # 🆕 То самое необязательное сообщение при отклике

class MeetingResponseInfo(BaseModel):
    id: UUID
    meeting_id: UUID | None = None # 🆕 ID встречи, чтобы открыть чат
    meeting_title: str | None = None  # 🆕 Название встречи для карточки
    meeting: dict | None = None  # 🆕 Полные данные о встрече
    user_id: UUID
    status: str  # pending, accepted, rejected, confirmed
    response_message: str | None = None  #  Сообщение отклика
    created_at: datetime
    
    # 🆕 Данные пользователя, который откликнулся (чтобы автор сразу видел, кто это)
    responder_username: str | None = None
    responder_avatar_url: str | None = None
    responder_age: int | None = None
    responder_gender: str | None = None
    
    is_read: bool = False

    model_config = {"from_attributes": True}
    

# --- Схемы для сообщений (Чат) ---

class MessageCreate(BaseModel):
    meeting_id: UUID
    text: str = Field(..., min_length=1, max_length=1000)

class MessageResponse(BaseModel):
    id: UUID
    meeting_id: UUID
    sender_id: UUID
    text: str
    is_read: bool
    created_at: datetime
    
    #  Данные отправителя (чтобы в чате было понятно, кто написал)
    sender_username: str | None = None
    sender_avatar_url: str | None = None
    
    model_config = {"from_attributes": True}

# 🆕 Схема для ответа со списком моих встреч и общим количеством непрочитанных откликов
class MyMeetingsResponse(BaseModel):
    meetings: list[MeetingResponse]
    total_unread_responses: int = 0