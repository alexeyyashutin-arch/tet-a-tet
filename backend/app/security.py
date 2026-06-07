from passlib.context import CryptContext

# Настраиваем bcrypt. Он добавляет "соль" и делает хеширование медленным, 
# чтобы хакеры не смогли подобрать пароли перебором.
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)