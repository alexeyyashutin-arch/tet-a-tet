from datetime import datetime, timedelta
from jose import JWTError, jwt
from .config import SECRET_KEY, ALGORITHM, ACCESS_TOKEN_EXPIRE_MINUTES

def create_access_token(data: dict, expires_delta: timedelta | None = None) -> str:
    """
    Создаёт JWT-токен с переданными данными и временем жизни.
    
    data: словарь с информацией (например, {"sub": user_id})
    expires_delta: как долго токен будет жить (по умолчанию из конфига)
    """
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    # Добавляем время истечения в токен
    to_encode.update({"exp": expire})
    
    # Кодируем токен с нашим секретным ключом
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    
    return encoded_jwt

def verify_token(token: str) -> dict | None:
    """
    Проверяет JWT-токен и возвращает данные из него.
    Если токен невалиден или истёк — возвращает None.
    """
    try:
        # Декодируем токен с проверкой подписи
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        # Если что-то пошло не так (подпись неверная, токен истёк и т.д.)
        return None