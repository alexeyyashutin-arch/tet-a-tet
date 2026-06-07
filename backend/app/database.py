import os
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase
from dotenv import load_dotenv

# Загружаем переменные из .env файла
load_dotenv()

# Получаем URL базы данных из переменных окружения
DATABASE_URL = os.getenv("DATABASE_URL")

# Создаём асинхронный "движок" (Engine). 
# Он управляет пулом соединений с базой. 
# echo=False, чтобы в консоль не выводился каждый SQL-запрос (иначе будет спам!)
engine = create_async_engine(DATABASE_URL, echo=False)

# Создаём фабрику сессий. Сессия — это наш "разговор" с базой данных.
# Мы будем открывать сессию, делать запросы и закрывать её.
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False
)

# Базовый класс для всех наших моделей (таблиц).
# От него будут наследоваться все таблицы (User, Match, Chat и т.д.)
class Base(DeclarativeBase):
    pass

# Асинхронная функция для получения сессии. 
# Мы будем использовать её как зависимость (Dependency) в FastAPI!
async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()