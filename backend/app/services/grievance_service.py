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
