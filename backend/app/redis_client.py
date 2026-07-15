import os
import json
import logging
from typing import Optional, Any
from redis.asyncio import Redis

# Настраиваем логгер
logger = logging.getLogger("redis_cache")

REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379/0")
redis_client: Optional[Redis] = None

async def get_redis() -> Redis:
    global redis_client
    if redis_client is None:
        redis_client = Redis.from_url(REDIS_URL, decode_responses=True)
    return redis_client

async def close_redis():
    global redis_client
    if redis_client:
        await redis_client.close()

async def cache_get(key: str) -> Optional[Any]:
    try:
        client = await get_redis()
        data = await client.get(key)
        if data:
            logger.info(f"🚀 Кэш HIT: {key}")
            return json.loads(data)
        else:
            logger.info(f"💾 Кэш MISS: {key}")
        return None
    except Exception as e:
        logger.error(f"❌ Ошибка чтения кэша: {e}")
        return None

async def cache_set(key: str, value: Any, expire: int = 300):
    try:
        client = await get_redis()
        # default=str нужен для сериализации UUID и datetime
        await client.set(key, json.dumps(value, default=str), ex=expire)
        logger.info(f"✅ Сохранено в кэш: {key} (на {expire} сек)")
    except Exception as e:
        logger.error(f"❌ Ошибка записи в кэш: {e}")

async def cache_delete(key: str):
    try:
        client = await get_redis()
        await client.delete(key)
    except Exception as e:
        logger.error(f"❌ Ошибка удаления кэша: {e}")

async def cache_delete_pattern(pattern: str):
    try:
        client = await get_redis()
        async for key in client.scan_iter(match=pattern):
            await client.delete(key)
        logger.info(f"🧹 Очищен кэш по маске: {pattern}")
    except Exception as e:
        logger.error(f"❌ Ошибка очистки кэша: {e}")
