import os
from dotenv import load_dotenv

load_dotenv()

# Секретный ключ для подписи JWT-токенов
# В продакшене это должна быть длинная случайная строка из переменных окружения!
SECRET_KEY = os.getenv("SECRET_KEY", "my-super-secret-key-for-development-only-change-in-production")

# Алгоритм шифрования
ALGORITHM = "HS256"

# Время жизни токена в минутах (например, 7 дней = 7 * 24 * 60 = 10080 минут)
ACCESS_TOKEN_EXPIRE_MINUTES = 10080