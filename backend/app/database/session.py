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


_connect_args = {}
if "localhost" not in settings.DATABASE_URL and "127.0.0.1" not in settings.DATABASE_URL:
    _connect_args["statement_cache_size"] = 0

engine = create_async_engine(
    settings.DATABASE_URL,
    echo=False,
    future=True,
    poolclass=NullPool,
    connect_args=_connect_args,
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
    from app.models.grievance_model import Base as GrievanceBase
    async with engine.begin() as conn:
        await conn.run_sync(GrievanceBase.metadata.create_all)
        for stmt in [
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS department_id VARCHAR(150);",
            "ALTER TABLE grievances ADD COLUMN IF NOT EXISTS assigned_official_id VARCHAR(36);",
            "ALTER TABLE grievances ADD COLUMN IF NOT EXISTS ai_processing_status VARCHAR(50);",
            "ALTER TABLE grievances ADD COLUMN IF NOT EXISTS ai_processed_at TIMESTAMP WITH TIME ZONE;",
            "ALTER TABLE grievances ADD COLUMN IF NOT EXISTS ai_model VARCHAR(100);",
            "ALTER TABLE grievances ADD COLUMN IF NOT EXISTS ai_error_message TEXT;",
            "ALTER TABLE grievances ADD COLUMN IF NOT EXISTS summary TEXT;",
            "ALTER TABLE grievances ADD COLUMN IF NOT EXISTS severity VARCHAR(20);",
        ]:
            try:
                await conn.execute(text(stmt))
            except Exception:
                pass
