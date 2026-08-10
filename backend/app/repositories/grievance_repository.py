import uuid
from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.grievance_model import (
    Grievance,
    GrievanceAuditLog,
    GrievanceStatus,
)
from app.schemas.grievance_schema import GrievanceDraftCreate


class GrievanceRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_grievance(
        self,
        citizen_id: str,
        draft_in: GrievanceDraftCreate,
        grievance_number: str,
    ) -> Grievance:
        grievance = Grievance(
            id=str(uuid.uuid4()),
            grievance_number=grievance_number,
            citizen_id=citizen_id,
            title=draft_in.title,
            description=draft_in.description,
            intake_mode=draft_in.intake_mode,
            original_language=draft_in.original_language,
            original_text=draft_in.original_text,
            translated_text=draft_in.translated_text,
            status=GrievanceStatus.DRAFT,
            priority=draft_in.priority,
            confirmed_location=draft_in.confirmed_location,
            location_sources=draft_in.location_sources,
        )
        self.db.add(grievance)

        # Automatic initial creation audit event
        audit_log = GrievanceAuditLog(
            id=str(uuid.uuid4()),
            grievance_id=grievance.id,
            actor_id=citizen_id,
            actor_role="citizen",
            action_type="created",
            previous_state=None,
            new_state=GrievanceStatus.DRAFT,
            remarks="Grievance draft initialized.",
        )
        self.db.add(audit_log)

        await self.db.flush()
        await self.db.refresh(grievance)
        return grievance

    async def get_by_id(self, grievance_id: str) -> Optional[Grievance]:
        result = await self.db.execute(
            select(Grievance).where(Grievance.id == grievance_id)
        )
        return result.scalar_one_or_none()

    async def get_user_grievance(
        self, grievance_id: str, citizen_id: str
    ) -> Optional[Grievance]:
        result = await self.db.execute(
            select(Grievance).where(
                Grievance.id == grievance_id,
                Grievance.citizen_id == citizen_id,
            )
        )
        return result.scalar_one_or_none()

    async def get_all_by_citizen_id(self, citizen_id: str) -> List[Grievance]:
        result = await self.db.execute(
            select(Grievance)
            .where(Grievance.citizen_id == citizen_id)
            .order_by(Grievance.created_at.desc())
        )
        return list(result.scalars().all())
