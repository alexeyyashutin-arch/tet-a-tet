import uuid
from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime, Integer, Text, Date, ForeignKey
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

    # Связи с фото
    photos = relationship("Photo", back_populates="owner", cascade="all, delete-orphan")
    granted_access = relationship("AlbumAccess", foreign_keys="AlbumAccess.owner_id", back_populates="owner", cascade="all, delete-orphan")
    received_access = relationship("AlbumAccess", foreign_keys="AlbumAccess.granted_to_id", back_populates="granted_to", cascade="all, delete-orphan")

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
    meeting_time = Column(String(10), nullable=False)  # "18:00"
    
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