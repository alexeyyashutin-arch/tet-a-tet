import os
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles # <-- Добавляем импорт
from .database import engine, Base
from . import models
from .routers import auth
from .routers import users
from .routers import photos 

app = FastAPI(
    title="TET-A-TET API",
    description="Премиальный приватный сервис для романтических встреч",
    version="1.0.0"
)

@app.on_event("startup")
async def startup():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    # Создаём папку для аватарок, если её нет
    os.makedirs("uploads", exist_ok=True)

# Подключаем роутеры
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(photos.router)

# 🆕 Раздаём статические файлы (наши аватарки) по адресу /uploads
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

@app.get("/")
async def root():
    return {"message": "Добро пожаловать в TET-A-TET. Здесь начинается магия. ✨"}