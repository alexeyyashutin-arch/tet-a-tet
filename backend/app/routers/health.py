"""
Healthcheck-эндпоинты для проверки работоспособности сервиса.

Содержит:
- GET / — приветственное сообщение
- GET /health/redis — проверка подключения к Redis
"""

from fastapi import APIRouter

from ..redis_client import get_redis

router = APIRouter()


@router.get("/")
async def root():
    """Приветственный эндпоинт — возвращает сообщение о том, что API жив."""
    return {"message": "Добро пожаловать в TET-A-TET. Здесь начинается магия. ✨"}


@router.get("/health/redis")
async def check_redis():
    """
    Проверяет подключение к Redis.

    Используется для мониторинга и отладки.
    Возвращает статус подключения.
    """
    try:
        client = await get_redis()
        await client.ping()
        return {"status": "ok", "redis": "connected"}
    except Exception as e:
        return {"status": "error", "redis": str(e)}