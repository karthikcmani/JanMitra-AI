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
        "ALTER TABLE grievances ADD COLUMN IF NOT EXISTS parent_id VARCHAR(36);",
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
        """
        UPDATE grievances
        SET department_id = 'Revenue & General Administration',
            category = 'Revenue & Land Reforms'
        WHERE (
            original_text ILIKE '%പുറമ്പോക്ക്%' 
            OR original_text ILIKE '%കയ്യേറ്റം%'
            OR original_text ILIKE '%തോട്%'
            OR original_text ILIKE '%തഹസിൽദാർ%'
            OR original_text ILIKE '%റീ-സർവേ%'
            OR title ILIKE '%തോട്%'
            OR title ILIKE '%പുറമ്പോക്ക്%'
            OR grievance_number = 'JM-2026-30098521'
        )
        AND (
            department_id = 'Kerala Water Authority (KWA)'
            OR category = 'Water Supply & Drainage'
            OR department_id IS NULL
        );
        """,
        """
        UPDATE grievance_analyses
        SET predicted_category = 'Revenue & General Administration'
        WHERE grievance_id IN (
            SELECT id FROM grievances 
            WHERE (
                original_text ILIKE '%പുറമ്പോക്ക്%' 
                OR original_text ILIKE '%കയ്യേറ്റം%'
                OR original_text ILIKE '%തോട്%'
                OR original_text ILIKE '%തഹസിൽദാർ%'
                OR title ILIKE '%തോട്%'
                OR title ILIKE '%പുറമ്പോക്ക്%'
                OR grievance_number = 'JM-2026-30098521'
            )
        );
        """,
        """
        UPDATE jurisdiction_recommendations
        SET department_name = 'Revenue & General Administration',
            recommended_authority = 'Tahsildar / Village Officer, Revenue Department'
        WHERE grievance_id IN (
            SELECT id FROM grievances 
            WHERE (
                original_text ILIKE '%പുറമ്പോക്ക്%' 
                OR original_text ILIKE '%കയ്യേറ്റം%'
                OR original_text ILIKE '%തോട്%'
                OR original_text ILIKE '%തഹസിൽദാർ%'
                OR title ILIKE '%തോട്%'
                OR title ILIKE '%പുറമ്പോക്ക്%'
                OR grievance_number = 'JM-2026-30098521'
            )
        );
        """,
    ]:
        async with engine.begin() as conn:
            try:
                await conn.execute(text(stmt))
            except Exception:
                pass

    try:
        await seed_default_users()
    except Exception as seed_err:
        import logging
        logging.getLogger(__name__).warning(f"Default users seeding notice: {seed_err}")


async def seed_default_users():
    """Seed dedicated department officials and administrators with active accounts."""
    import uuid
    from sqlalchemy import select
    from app.core.security import get_password_hash
    from app.models.user_model import User

    default_users = [
        {
            "email": "admin@janmitra.gov.in",
            "full_name": "State Grievance Administrator",
            "role": "admin",
            "department_id": None,
            "phone": "9876543210",
            "password": "Admin@JanMitra2026",
        },
        {
            "email": "official.revenue@janmitra.gov.in",
            "full_name": "K. Ramanathan (Tahsildar & Executive Magistrate)",
            "role": "official",
            "department_id": "Revenue & General Administration",
            "phone": "9876543211",
            "password": "Official@Revenue2026",
        },
        {
            "email": "official.kwa@janmitra.gov.in",
            "full_name": "P. S. Suresh (Assistant Executive Engineer, KWA)",
            "role": "official",
            "department_id": "Kerala Water Authority (KWA)",
            "phone": "9876543212",
            "password": "Official@KWA2026",
        },
        {
            "email": "official.pwd@janmitra.gov.in",
            "full_name": "M. Vinod (Assistant Executive Engineer, PWD Roads)",
            "role": "official",
            "department_id": "Public Works Department (PWD)",
            "phone": "9876543213",
            "password": "Official@PWD2026",
        },
        {
            "email": "official.lsgd@janmitra.gov.in",
            "full_name": "Anitha V. Nair (Secretary, LSGD / Grama Panchayat)",
            "role": "official",
            "department_id": "Local Self Government Department (LSGD / Panchayat)",
            "phone": "9876543214",
            "password": "Official@LSGD2026",
        },
        {
            "email": "official.kseb@janmitra.gov.in",
            "full_name": "G. Harikumar (Assistant Engineer, KSEB Section)",
            "role": "official",
            "department_id": "Kerala State Electricity Board (KSEB)",
            "phone": "9876543215",
            "password": "Official@KSEB2026",
        },
        {
            "email": "citizen@janmitra.gov.in",
            "full_name": "Gopalan Nair (Citizen)",
            "role": "citizen",
            "department_id": None,
            "phone": "9876543216",
            "password": "Citizen@JanMitra2026",
        },
    ]

    async with AsyncSessionLocal() as db:
        for u_data in default_users:
            stmt = select(User).where(User.email == u_data["email"])
            res = await db.execute(stmt)
            existing = res.scalar_one_or_none()
            if not existing:
                pwd_hash = get_password_hash(u_data["password"])
                new_user = User(
                    id=str(uuid.uuid4()),
                    email=u_data["email"],
                    full_name=u_data["full_name"],
                    role=u_data["role"],
                    department_id=u_data["department_id"],
                    phone=u_data["phone"],
                    password_hash=pwd_hash,
                    is_active=True,
                )
                db.add(new_user)
            else:
                existing.role = u_data["role"]
                existing.department_id = u_data["department_id"]
                existing.full_name = u_data["full_name"]
                existing.password_hash = get_password_hash(u_data["password"])
                existing.is_active = True
        await db.commit()
