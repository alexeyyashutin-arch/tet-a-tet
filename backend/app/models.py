import uuid
from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime, Integer, Text, Date, ForeignKey, Float
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from .database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    phone = Column(String(20), unique=True, index=True, nullable=False)
    is_verified = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    
    # Поля для SMS-кода и защиты
    otp_code = Column(String(4), nullable=True)
    otp_expires_at = Column(DateTime(timezone=True), nullable=True)
    last_code_sent_at = Column(DateTime(timezone=True), nullable=True)
    failed_attempts = Column(Integer, default=0, nullable=False)
    blocked_until = Column(DateTime(timezone=True), nullable=True)
    
    # Профиль
    username = Column(String(50), nullable=True)
    birth_date = Column(Date, nullable=True)
    gender = Column(String(20), nullable=True)
    bio = Column(Text, nullable=True)
    avatar_url = Column(String(255), nullable=True)
    city = Column(String(100), nullable=True)       # Название города (например, "Москва")
    latitude = Column(Float, nullable=True)         # Широта (например, 55.7558)
    longitude = Column(Float, nullable=True)        # Долгота (например, 37.6173)

    # 🆕 Новые поля профиля для умного подбора
    alcohol_attitude = Column(String(50), nullable=True)   # "Положительное", "Нейтральное", "Отрицательное"
    smoking_attitude = Column(String(100), nullable=True)  # "Категорически не приемлю", "Не курю, но не против", "Курю"
    height = Column(Integer, nullable=True)                # Рост в см
    weight = Column(Integer, nullable=True)                # Вес в кг
    body_type = Column(String(50), nullable=True)          # "Худощавое", "Обычное", "Спортивное", "Есть пара лишних кг", "Полное"
    marital_status = Column(String(50), nullable=True)     # "В браке", "Свободен"
    has_children = Column(String(10), nullable=True)       # "Есть", "Нет"
   #  Токен для Push-уведомлений
    fcm_token = Column(Text, nullable=True)

    # Связи с фото
    photos = relationship("Photo", back_populates="owner", cascade="all, delete-orphan")
    granted_access = relationship("AlbumAccess", foreign_keys="AlbumAccess.owner_id", back_populates="owner", cascade="all, delete-orphan")
    received_access = relationship("AlbumAccess", foreign_keys="AlbumAccess.granted_to_id", back_populates="granted_to", cascade="all, delete-orphan")
    meeting_responses = relationship("MeetingResponse", backref="user", cascade="all, delete-orphan")
    sent_messages = relationship("Message", backref="sender", cascade="all, delete-orphan")

class Photo(Base):
    __tablename__ = "photos"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    album_type = Column(String(10), nullable=False)  # "public" или "private"
    url = Column(String(255), nullable=False)
    uploaded_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    
    owner = relationship("User", back_populates="photos")

class AlbumAccess(Base):
    __tablename__ = "album_access"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    granted_to_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    granted_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    
    owner = relationship("User", foreign_keys=[owner_id], back_populates="granted_access")
    granted_to = relationship("User", foreign_keys=[granted_to_id], back_populates="received_access")

class Meeting(Base):
    __tablename__ = "meetings"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    
    # Основная информация
    title = Column(String(200), nullable=False)  # "Хочу поужинать в ресторане Река"
    description = Column(Text, nullable=True)  # Подробное описание
    
    # Дата и время
    meeting_date = Column(Date, nullable=False)
    meeting_time = Column(String(10), nullable=True)  # "18:00"
    
    # Место
    location = Column(String(200), nullable=True)  # "Ресторан Река"
    
    # Пожелания к спутнице/спутнику
    partner_wishes = Column(Text, nullable=True)
    
    # Финансы: "self", "split", "partner", "none"
    finance = Column(String(20), nullable=False, default="self")
    
    # Статус: "active", "completed", "cancelled"
    status = Column(String(20), nullable=False, default="active")
    
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    
    # Связь с пользователем
    creator = relationship("User", backref="meetings")

    # 🆕 Добавляем связи для откликов и сообщений
    responses = relationship("MeetingResponse", backref="meeting", cascade="all, delete-orphan")
    messages = relationship("Message", backref="meeting", cascade="all, delete-orphan")

class MeetingResponse(Base):
    __tablename__ = "meeting_responses"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    meeting_id = Column(UUID(as_uuid=True), ForeignKey("meetings.id"), nullable=False, index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    
    # Необязательное сообщение при отклике
    response_message = Column(Text, nullable=True)
    
    # Статусы: "pending", "accepted", "rejected", "confirmed"
    status = Column(String(20), nullable=False, default="pending") 
    
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)


class Message(Base):
    __tablename__ = "messages"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    meeting_id = Column(UUID(as_uuid=True), ForeignKey("meetings.id"), nullable=False, index=True)
    sender_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    
    text = Column(Text, nullable=False)
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)