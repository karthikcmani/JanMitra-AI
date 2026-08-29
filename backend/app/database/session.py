from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.pool import NullPool
from app.core.config import settings


class Base(DeclarativeBase):
    pass


engine = create_async_engine(
    settings.DATABASE_URL,
    echo=False,
    future=True,
    poolclass=NullPool,
)


AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def init_db_schema():
    from sqlalchemy import text
    async with engine.begin() as conn:
        for stmt in [
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS department_id VARCHAR(150);",
            "ALTER TABLE grievances ADD COLUMN IF NOT EXISTS assigned_official_id VARCHAR(36);",
        ]:
            try:
                await conn.execute(text(stmt))
            except Exception:
                pass

