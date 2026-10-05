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
            if session.is_active and session.in_transaction():
                await session.commit()
        except Exception:
            if session.is_active and session.in_transaction():
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
            "ALTER TABLE grievances ADD COLUMN IF NOT EXISTS priority_score INTEGER DEFAULT 50;",
            "ALTER TABLE grievances ADD COLUMN IF NOT EXISTS official_clarification_question TEXT;",
            "ALTER TABLE grievance_attachments ADD COLUMN IF NOT EXISTS file_content_base64 TEXT;",
            """
            DELETE FROM grievance_interview_questions
            WHERE id IN (
                SELECT id FROM (
                    SELECT id, ROW_NUMBER() OVER (PARTITION BY grievance_id, question, status ORDER BY created_at ASC) as rnum
                    FROM grievance_interview_questions
                    WHERE status = 'PENDING'
                ) t
                WHERE t.rnum > 1
            );
            """,
            """
            UPDATE grievances
            SET department_id = 'Public Works Department (PWD)',
                category = 'Roads & Public Infrastructure'
            WHERE (grievance_number = 'JM-2026-07393063' OR original_text ILIKE '%റോഡ്%' OR title ILIKE '%റോഡ്%')
              AND (department_id IS NULL OR department_id = 'Kerala Water Authority (KWA)');
            """,
            """
            UPDATE grievance_analyses
            SET predicted_category = 'Public Works Department (PWD)'
            WHERE grievance_id IN (
                SELECT id FROM grievances 
                WHERE grievance_number = 'JM-2026-07393063' 
                   OR (original_text ILIKE '%റോഡ്%' AND (department_id = 'Public Works Department (PWD)' OR department_id IS NULL))
            );
            """,
            """
            UPDATE grievances
            SET assigned_official_id = (SELECT id FROM users WHERE email = 'official.pwd@janmitra.gov.in' LIMIT 1)
            WHERE department_id = 'Public Works Department (PWD)';
            """,
        ]:
            try:
                await conn.execute(text(stmt))
            except Exception:
                pass
