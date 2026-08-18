import uuid
from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.grievance_model import (
    Grievance,
    GrievanceAttachment,
    GrievanceAuditLog,
    GrievanceStatus,
    ExtractionStatus,
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
        res = await self.db.execute(
            select(Grievance)
            .options(selectinload(Grievance.audit_logs))
            .where(Grievance.id == grievance.id)
        )
        return res.scalar_one()

    async def get_by_id(self, grievance_id: str) -> Optional[Grievance]:
        result = await self.db.execute(
            select(Grievance)
            .options(selectinload(Grievance.audit_logs))
            .where(Grievance.id == grievance_id)
        )
        return result.scalar_one_or_none()

    async def get_user_grievance(
        self, grievance_id: str, citizen_id: str
    ) -> Optional[Grievance]:
        result = await self.db.execute(
            select(Grievance)
            .options(selectinload(Grievance.audit_logs))
            .where(
                Grievance.id == grievance_id,
                Grievance.citizen_id == citizen_id,
            )
        )
        return result.scalar_one_or_none()

    async def get_all_by_citizen_id(self, citizen_id: str) -> List[Grievance]:
        result = await self.db.execute(
            select(Grievance)
            .options(selectinload(Grievance.audit_logs))
            .where(Grievance.citizen_id == citizen_id)
            .order_by(Grievance.created_at.desc())
        )
        return list(result.scalars().all())


    async def create_attachment(
        self,
        grievance_id: str,
        actor_id: str,
        attachment_type: str,
        original_filename: str,
        mime_type: str,
        storage_path: str,
        file_size_bytes: Optional[int] = None,
    ) -> GrievanceAttachment:
        attachment = GrievanceAttachment(
            id=str(uuid.uuid4()),
            grievance_id=grievance_id,
            attachment_type=attachment_type,
            original_filename=original_filename,
            mime_type=mime_type,
            storage_path=storage_path,
            file_size_bytes=file_size_bytes,
        )
        self.db.add(attachment)

        # Record audit log for attachment addition
        audit_log = GrievanceAuditLog(
            id=str(uuid.uuid4()),
            grievance_id=grievance_id,
            actor_id=actor_id,
            actor_role="citizen",
            action_type="attachment_added",
            previous_state=None,
            new_state=None,
            remarks=f"Attachment '{original_filename}' uploaded successfully.",
        )
        self.db.add(audit_log)

        await self.db.flush()
        await self.db.refresh(attachment)
        return attachment

    async def get_attachment(self, attachment_id: str) -> Optional[GrievanceAttachment]:
        result = await self.db.execute(
            select(GrievanceAttachment).where(
                GrievanceAttachment.id == attachment_id
            )
        )
        return result.scalar_one_or_none()

    async def get_attachment_for_grievance(
        self, grievance_id: str, attachment_id: str
    ) -> Optional[GrievanceAttachment]:
        result = await self.db.execute(
            select(GrievanceAttachment).where(
                GrievanceAttachment.id == attachment_id,
                GrievanceAttachment.grievance_id == grievance_id,
            )
        )
        return result.scalar_one_or_none()

    async def update_attachment_extraction(
        self,
        attachment: GrievanceAttachment,
        extraction_status: str,
        extracted_text: Optional[str] = None,
        confidence_score: Optional[float] = None,
        engine_name: Optional[str] = None,
        error_message: Optional[str] = None,
        actor_id: Optional[str] = None,
    ) -> GrievanceAttachment:
        attachment.extraction_status = extraction_status
        attachment.raw_extracted_text = extracted_text
        attachment.extraction_confidence = confidence_score
        attachment.extraction_engine = engine_name
        attachment.extraction_error = error_message
        attachment.extracted_at = datetime.now(timezone.utc)

        # Audit log entry for extraction completion or failure
        action_type = (
            "extraction_completed"
            if extraction_status == ExtractionStatus.COMPLETED
            else "extraction_failed"
        )
        audit_log = GrievanceAuditLog(
            id=str(uuid.uuid4()),
            grievance_id=attachment.grievance_id,
            actor_id=actor_id,
            actor_role="citizen" if actor_id else "system",
            action_type=action_type,
            previous_state=None,
            new_state=extraction_status,
            remarks=f"Extraction engine '{engine_name}' finished with status '{extraction_status}'.",
        )
        self.db.add(audit_log)

        await self.db.flush()
        await self.db.refresh(attachment)
        return attachment
