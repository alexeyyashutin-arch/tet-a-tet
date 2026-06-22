import os
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from .database import engine, Base
from . import models
from .routers import auth
from .routers import users
from .routers import photos 
from .routers import meetings
from .routers import responses
from .routers import messages
from .routers import verification
from .redis_client import get_redis, close_redis  # 🆕 Подключаем Redis

app = FastAPI(
    title="TET-A-TET API",
    description="Премиальный приватный сервис для романтических встреч",
    version="1.0.0"
)

@app.on_event("startup")
async def startup():
    # Создаём таблицы в базе данных
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    # 🆕 Инициализируем Redis
    await get_redis()
    print("✅ Redis подключён!")
    
    # Создаём папку для аватарок, если её нет
    os.makedirs("uploads", exist_ok=True)

@app.on_event("shutdown")
async def shutdown():
    # 🆕 Закрываем соединение с Redis при остановке
    await close_redis()
    print("🔌 Redis отключён")

# Подключаем роутеры
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(photos.router)
app.include_router(meetings.router)
app.include_router(responses.router)
app.include_router(messages.router)
app.include_router(verification.router)

# Раздаём статические файлы (наши аватарки) по адресу /uploads
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

@app.get("/")
async def root():
    return {"message": "Добро пожаловать в TET-A-TET. Здесь начинается магия. ✨"}

# 🆕 Эндпоинт для проверки статуса Redis (для тестирования)
@app.get("/health/redis")
async def check_redis():
    try:
        client = await get_redis()
        await client.ping()
        return {"status": "ok", "redis": "connected"}
    except Exception as e:
        return {"status": "error", "redis": str(e)}


import os
from jose import jwt, JWTError
from fastapi import WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from .websocket_manager import manager
from .models import Message, User
from .database import engine # Убедись, что engine импортирован

# 🆕 WebSocket для мгновенных сообщений
@app.websocket("/ws/{meeting_id}")
async def websocket_endpoint(websocket: WebSocket, meeting_id: str, token: str):
    # 1. Проверяем токен (в WebSockets токен передаётся в URL: ?token=...)
    try:
        # ВАЖНО: Замени 'your-secret-key' на тот же секретный ключ, который ты используешь в dependencies.py для JWT!
        SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key") 
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        user_id = payload.get("sub")
        if user_id is None:
            await websocket.close(code=4001)
            return
    except JWTError:
        await websocket.close(code=4001)
        return

    # 2. Подключаем пользователя к комнате чата
    await manager.connect(websocket, meeting_id)
    
    try:
        while True:
            # Ждём сообщение от клиента
            data = await websocket.receive_json()
            
            if data.get("type") == "message":
                text = data.get("text")
                
                # 3. Сохраняем сообщение в БД (асинхронно)
                async with AsyncSession(engine) as db:
                    new_message = Message(
                        meeting_id=meeting_id,
                        sender_id=user_id,
                        text=text,
                        is_read=False
                    )
                    db.add(new_message)
                    await db.commit()
                    await db.refresh(new_message)
                    
                    # Получаем имя отправителя для красивого отображения
                    user = await db.get(User, user_id)
                    sender_name = user.username if user else "Аноним"
                    sender_avatar = user.avatar_url if user else None

                # 4. Мгновенно рассылаем всем в комнате!
                await manager.broadcast(meeting_id, {
                    "type": "new_message",
                    "id": str(new_message.id),
                    "text": text,
                    "sender_id": user_id,
                    "sender_username": sender_name,
                    "sender_avatar_url": sender_avatar,
                    "created_at": new_message.created_at.isoformat()
                })
                
    except WebSocketDisconnect:
        manager.disconnect(websocket, meeting_id)