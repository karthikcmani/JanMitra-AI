import uuid
import time
from pathlib import Path
from typing import List, Tuple
from fastapi import HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.grievance_model import AttachmentType
from app.repositories.grievance_repository import GrievanceRepository
from app.schemas.grievance_schema import (
    GrievanceAttachmentResponse,
    GrievanceDraftCreate,
    GrievanceResponse,
)
from app.services.extraction_service import (
    BaseExtractionAdapter,
    NormalizedExtractionResult,
)
from app.services.storage_service import LocalFileSystemStorage

ALLOWED_MIME_TYPES = {
    "image/jpeg": [".jpg", ".jpeg"],
    "image/png": [".png"],
    "image/webp": [".webp"],
    "application/pdf": [".pdf"],
}

MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024  # 10MB limit


class GrievanceService:
    def __init__(self, db: AsyncSession, storage: LocalFileSystemStorage | None = None):
        self.repo = GrievanceRepository(db)
        self.storage = storage or LocalFileSystemStorage()

    @staticmethod
    def _generate_grievance_number() -> str:
        timestamp_ms = int(time.time() * 1000) % 100000000
        return f"JM-2026-{timestamp_ms:08d}"

    async def create_draft(
        self, citizen_id: str, draft_in: GrievanceDraftCreate
    ) -> GrievanceResponse:
        grievance_no = self._generate_grievance_number()
        db_grievance = await self.repo.create_grievance(
            citizen_id=citizen_id,
            draft_in=draft_in,
            grievance_number=grievance_no,
        )
        return GrievanceResponse.model_validate(db_grievance)

    async def get_citizen_grievances(
        self, citizen_id: str
    ) -> List[GrievanceResponse]:
        grievances = await self.repo.get_all_by_citizen_id(citizen_id)
        return [GrievanceResponse.model_validate(g) for g in grievances]

    async def get_grievance_by_id(
        self, grievance_id: str, citizen_id: str
    ) -> GrievanceResponse:
        grievance = await self.repo.get_user_grievance(grievance_id, citizen_id)
        if not grievance:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Grievance not found.",
            )
        return GrievanceResponse.model_validate(grievance)

    async def upload_attachment(
        self,
        citizen_id: str,
        grievance_id: str,
        file: UploadFile,
        attachment_type: str = AttachmentType.HANDWRITTEN_PETITION,
    ) -> GrievanceAttachmentResponse:
        # 1. Ownership verification
        grievance = await self.repo.get_user_grievance(grievance_id, citizen_id)
        if not grievance:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Grievance not found.",
            )

        # 2. MIME & Extension validation
        mime_type = (file.content_type or "").lower()
        original_filename = file.filename or "uploaded_file"
        file_ext = Path(original_filename).suffix.lower()

        if mime_type not in ALLOWED_MIME_TYPES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid file type. Supported types: JPEG, PNG, WEBP, PDF.",
            )

        valid_extensions = ALLOWED_MIME_TYPES[mime_type]
        if file_ext not in valid_extensions:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"File extension '{file_ext}' does not match declared MIME type '{mime_type}'.",
            )

        # 3. File size validation
        file.file.seek(0, 2)
        file_size = file.file.tell()
        file.file.seek(0)

        if file_size > MAX_FILE_SIZE_BYTES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="File size exceeds maximum allowed limit (10MB).",
            )

        # 4. Generate safe server-side storage filename
        server_filename = f"{uuid.uuid4().hex}{file_ext}"

        # 5. Store file on physical storage
        try:
            storage_path = await self.storage.save_file(
                grievance_id=grievance_id,
                filename=server_filename,
                file_data=file.file,
            )
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to store file: {str(e)}",
            )

        # 6. Database record creation with orphaned file cleanup fallback
        try:
            attachment = await self.repo.create_attachment(
                grievance_id=grievance_id,
                actor_id=citizen_id,
                attachment_type=attachment_type,
                original_filename=original_filename,
                mime_type=mime_type,
                storage_path=storage_path,
                file_size_bytes=file_size,
            )
        except Exception as e:
            # Clean up orphaned physical file if DB insertion fails
            await self.storage.delete_file(storage_path)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to record attachment metadata in database.",
            )

        # 7. Automatically execute fast document OCR extraction
        try:
            await self.extract_attachment_content(
                citizen_id=citizen_id,
                grievance_id=grievance_id,
                attachment_id=attachment.id,
            )
            refreshed = await self.repo.get_attachment_for_grievance(
                grievance_id=grievance_id, attachment_id=attachment.id
            )
            if refreshed:
                attachment = refreshed
        except Exception:
            pass  # Do not block upload if background OCR encounters non-fatal issue

        return GrievanceAttachmentResponse.model_validate(attachment)

    async def get_attachment_file(
        self, citizen_id: str, grievance_id: str, attachment_id: str
    ) -> Tuple[Path, str, str]:
        # 1. Ownership verification
        grievance = await self.repo.get_user_grievance(grievance_id, citizen_id)
        if not grievance:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Grievance not found.",
            )

        # 2. Attachment verification
        attachment = await self.repo.get_attachment_for_grievance(
            grievance_id=grievance_id, attachment_id=attachment_id
        )
        if not attachment:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Attachment not found.",
            )

        # 3. Resolve file on disk
        try:
            abs_path = self.storage.get_absolute_path(attachment.storage_path)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Attachment path invalid.",
            )

        if not abs_path.exists() or not abs_path.is_file():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Stored attachment file not found.",
            )

        return abs_path, attachment.mime_type, attachment.original_filename

    async def extract_attachment_content(
        self,
        citizen_id: str,
        grievance_id: str,
        attachment_id: str,
        extractor: BaseExtractionAdapter | None = None,
    ) -> NormalizedExtractionResult:
        from datetime import datetime, timezone
        from app.models.grievance_model import ExtractionStatus, GrievanceStatus
        from app.services.extraction_service import FastAutoExtractionAdapter

        extractor_adapter = extractor or FastAutoExtractionAdapter()

        # 1. Ownership verification
        grievance = await self.repo.get_user_grievance(grievance_id, citizen_id)
        if not grievance:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Grievance not found.",
            )

        # 2. Attachment verification
        attachment = await self.repo.get_attachment_for_grievance(
            grievance_id=grievance_id, attachment_id=attachment_id
        )
        if not attachment:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Attachment not found.",
            )

        # 3. Perform extraction via abstraction adapter
        try:
            abs_path = self.storage.get_absolute_path(attachment.storage_path)
            result = await extractor_adapter.extract_content(
                attachment=attachment, file_path=abs_path
            )
        except Exception as e:
            result = NormalizedExtractionResult(
                source_type=attachment.attachment_type,
                source_attachment_id=attachment.id,
                original_language="ml",
                extracted_text=None,
                extraction_status=ExtractionStatus.FAILED,
                confidence_score=None,
                engine_name="mock_adapter_v1",
                processed_at=datetime.now(timezone.utc),
                error_message=f"Extraction processing error: {str(e)}",
            )

        # 4. Persist extraction result into PostgreSQL database
        updated_att = await self.repo.update_attachment_extraction(
            attachment=attachment,
            extraction_status=result.extraction_status,
            extracted_text=result.extracted_text,
            confidence_score=result.confidence_score,
            engine_name=result.engine_name,
            error_message=result.error_message,
            actor_id=citizen_id,
        )

        # 5. Update grievance original_text if draft
        if result.extraction_status == ExtractionStatus.COMPLETED and result.extracted_text:
            if not grievance.original_text:
                grievance.original_text = result.extracted_text
                grievance.status = GrievanceStatus.INTAKE_RECEIVED
                await self.repo.db.flush()

        # 6. Return NormalizedExtractionResult
        return NormalizedExtractionResult(
            source_type=updated_att.attachment_type,
            source_attachment_id=updated_att.id,
            original_language="ml",
            extracted_text=updated_att.raw_extracted_text,
            extraction_status=updated_att.extraction_status,
            confidence_score=updated_att.extraction_confidence,
            engine_name=updated_att.extraction_engine or "mock_ocr_v1",
            processed_at=updated_att.extracted_at or datetime.now(timezone.utc),
            error_message=updated_att.extraction_error,
        )

    async def submit_clarification(
        self, citizen_id: str, grievance_id: str, response_text: str
    ) -> GrievanceResponse:
        from app.models.grievance_model import GrievanceAuditLog, GrievanceStatus
        grievance = await self.repo.get_user_grievance(grievance_id, citizen_id)
        if not grievance:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Grievance not found.",
            )

        prev_status = grievance.status
        grievance.status = GrievanceStatus.UNDER_PROCESSING

        audit_log = GrievanceAuditLog(
            id=str(uuid.uuid4()),
            grievance_id=grievance_id,
            actor_id=citizen_id,
            actor_role="citizen",
            action_type="CLARIFICATION_PROVIDED",
            previous_state=prev_status,
            new_state=grievance.status,
            remarks=f"Citizen Clarification Response: {response_text}",
        )
        self.repo.db.add(audit_log)
        await self.repo.db.commit()
        self.repo.db.expire_all()

        updated = await self.repo.get_user_grievance(grievance_id, citizen_id)
        return GrievanceResponse.model_validate(updated)


