"""
Главная точка входа приложения TET-A-TET.

Здесь всё начинается и заканчивается:
- Настройка жизненного цикла приложения (lifespan) — БД, Redis, папки
- Подключение всех роутеров
- Раздача статических файлов

Важно: этот файл не должен содержать бизнес-логику!
Вся логика живёт в роутерах (routers/) и сервисах (services/).
"""

import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from .database import engine, Base
from . import models
from .redis_client import get_redis, close_redis

# Импортируем все роутеры
from .routers import auth, users, photos, meetings, responses, messages, verification, admin, websocket
from .routers import health  # root и healthcheck


# ============================================================
# ⏱️ LIFESPAN — управление жизненным циклом приложения
# ============================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Современный способ управления запуском и остановкой приложения.

    Всё, что ДО yield — выполняется при старте (аналог @app.on_event("startup")).
    Всё, что ПОСЛЕ yield — выполняется при остановке (аналог @app.on_event("shutdown")).

    Почему это лучше старых on_event:
    - Код startup и shutdown в одном месте, легко читать
    - Можно обмениваться данными между startup и shutdown через yield
    - Не устареет в будущих версиях FastAPI
    """
    # --- ЗАПУСК: подготовка окружения ---
    print("🚀 Запуск TET-A-TET API...", flush=True)

    # Создаём таблицы в БД (если их ещё нет)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    # Подключаемся к Redis для кэширования
    await get_redis()
    print("✅ Redis подключён!", flush=True)

    # Создаём папку для загруженных файлов
    os.makedirs("uploads", exist_ok=True)

    print("✨ TET-A-TET готов к работе!", flush=True)

    # --- ПРИЛОЖЕНИЕ РАБОТАЕТ ---
    yield

    # --- ОСТАНОВКА: уборка за собой ---
    print("🔌 Остановка TET-A-TET API...", flush=True)
    await close_redis()
    print("👋 До новых встреч!", flush=True)


# ============================================================
# 🏗️ СОЗДАНИЕ ПРИЛОЖЕНИЯ
# ============================================================

app = FastAPI(
    title="TET-A-TET API",
    description="Премиальный приватный сервис для романтических встреч",
    version="1.0.0",
    lifespan=lifespan,  # <-- вместо устаревших @app.on_event()
)


# ============================================================
# 🚦 ПОДКЛЮЧЕНИЕ РОУТЕРОВ
# ============================================================

app.include_router(health.router)       # GET / и /health/redis
app.include_router(auth.router)         # /auth/*
app.include_router(users.router)        # /users/*
app.include_router(photos.router)       # /photos/*
app.include_router(meetings.router)     # /meetings/*
app.include_router(responses.router)    # /responses/*
app.include_router(messages.router)     # /messages/*
app.include_router(verification.router) # /verification/*
app.include_router(admin.router)        # /admin/*
app.include_router(websocket.router)    # /ws/* (чат в реальном времени)


# ============================================================
# 📁 СТАТИЧЕСКИЕ ФАЙЛЫ
# ============================================================

# Раздаём загруженные фото и аватарки по адресу /uploads
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")