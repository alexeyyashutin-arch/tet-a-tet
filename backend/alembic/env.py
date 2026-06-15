from logging.config import fileConfig
from sqlalchemy import engine_from_config
from sqlalchemy import pool
from alembic import context

# 🆕 Импорт твоего Base и моделей
from app.models import Base

# this is the Alembic Config object
config = context.config

# Interpret the config file for Python logging.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# 🆕 Говорим Alembic смотреть на наши модели
target_metadata = Base.metadata

def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online() -> None:
    """Run migrations in 'online' mode."""
    import os
    import sqlalchemy
    
    # 🆕 Берём URL напрямую из переменных окружения Docker
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise ValueError("Переменная DATABASE_URL не найдена в окружении!")
    
    # 🆕 Заменяем asyncpg на psycopg2 для синхронной работы
    sync_url = database_url.replace("+asyncpg", "+psycopg2")
    
    # 🆕 Создаём подключение напрямую, игнорируя alembic.ini!
    connectable = sqlalchemy.create_engine(sync_url, poolclass=pool.NullPool)

    with connectable.connect() as connection:
        context.configure(
            connection=connection, target_metadata=target_metadata
        )
        with context.begin_transaction():
            context.run_migrations()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()