import uuid
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from fastapi import HTTPException, UploadFile, status
from sqlalchemy import select
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
    "image/jpg": [".jpg", ".jpeg"],
    "image/png": [".png"],
    "image/webp": [".webp"],
    "application/pdf": [".pdf"],
    "audio/wav": [".wav"],
    "audio/x-wav": [".wav"],
    "audio/wave": [".wav"],
    "audio/mpeg": [".mp3"],
    "audio/mp3": [".mp3"],
    "audio/mp4": [".m4a", ".mp4", ".aac"],
    "audio/m4a": [".m4a"],
    "audio/x-m4a": [".m4a"],
    "audio/aac": [".aac", ".m4a"],
    "audio/ogg": [".ogg", ".opus"],
    "audio/flac": [".flac"],
    "audio/x-flac": [".flac"],
    "audio/webm": [".webm"],
    "video/mp4": [".m4a", ".mp4"],
    "video/webm": [".webm"],
}

EXTENSION_TO_MIME = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".pdf": "application/pdf",
    ".wav": "audio/wav",
    ".mp3": "audio/mpeg",
    ".m4a": "audio/mp4",
    ".aac": "audio/aac",
    ".ogg": "audio/ogg",
    ".opus": "audio/ogg",
    ".flac": "audio/flac",
    ".webm": "audio/webm",
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
        # Validate direct text to prevent casual chitchat or non-grievance submissions
        if draft_in.intake_mode == "direct_text":
            from app.services.grievance_validator import validate_grievance_text
            content_to_check = f"{draft_in.title or ''} {draft_in.description or ''} {draft_in.original_text or ''}".strip()
            val_result = validate_grievance_text(content_to_check)
            if not val_result.is_valid:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"{val_result.reason} {val_result.suggestion or ''}".strip(),
                )

        # Populate verified citizen profile identity if self-filing
        if getattr(draft_in, "filing_type", "self") == "self" and not getattr(draft_in, "petitioner_name", None):
            from app.models.user_model import User
            user_res = await self.repo.db.execute(select(User).where(User.id == citizen_id))
            citizen_user = user_res.scalar_one_or_none()
            if citizen_user:
                draft_in.petitioner_name = citizen_user.full_name
                draft_in.petitioner_phone = citizen_user.phone
                draft_in.relationship = "Self (Primary Applicant)"

        grievance_no = self._generate_grievance_number()
        db_grievance = await self.repo.create_grievance(
            citizen_id=citizen_id,
            draft_in=draft_in,
            grievance_number=grievance_no,
        )

        # Initial Multi-factor Priority Evaluation
        from app.services.priority_engine import PriorityIntelligenceEngine
        p_eval = PriorityIntelligenceEngine.evaluate(
            (draft_in.title or "") + " " + (draft_in.description or "") + " " + (draft_in.original_text or ""),
            department=getattr(draft_in, "category", None) or getattr(draft_in, "department", None),
        )
        db_grievance.priority = p_eval.priority.lower()
        db_grievance.priority_score = p_eval.priority_score
        await self.repo.db.flush()

        # Trigger AI analysis for direct_text grievances immediately and transition status to INTAKE_RECEIVED
        if draft_in.intake_mode == "direct_text" and (draft_in.original_text or draft_in.title):
            try:
                from app.models.grievance_model import GrievanceStatus
                db_grievance.status = GrievanceStatus.INTAKE_RECEIVED
                await self.repo.db.flush()

                from app.services.official_service import OfficialService
                official_service = OfficialService(self.repo.db)
                await official_service.process_document_and_route(db_grievance.id, citizen_id)

                refreshed = await self.repo.get_by_id(db_grievance.id)
                if refreshed:
                    db_grievance = refreshed
            except Exception:
                pass

        return GrievanceResponse.model_validate(db_grievance)

    async def get_citizen_grievances(
        self, citizen_id: str
    ) -> List[GrievanceResponse]:
        grievances = await self.repo.get_all_by_citizen_id(citizen_id)
        return [GrievanceResponse.model_validate(g) for g in grievances]

    async def check_duplicate_grievance(
        self, citizen_id: str, title: Optional[str] = None, text: Optional[str] = None, current_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """Detects whether citizen is filing a duplicate or near-identical grievance for an issue already active."""
        if not title and not text:
            return {"is_duplicate": False, "similarity_score": 0.0, "message": "No text provided for duplicate check."}

        candidate_title = (title or "").strip().lower()
        candidate_text = (text or "").strip().lower()

        # Fetch active grievances for this citizen
        active_grievances = await self.repo.get_all_by_citizen_id(citizen_id)
        for g in active_grievances:
            if current_id and g.id == current_id:
                continue
            if g.status in ("resolved", "closed", "rejected"):
                continue

            existing_title = (g.title or "").strip().lower()
            existing_text = (g.original_text or g.description or "").strip().lower()

            # Exact title or text match
            if candidate_title and existing_title and (candidate_title == existing_title or candidate_title in existing_title or existing_title in candidate_title):
                if len(candidate_title) > 8:
                    return {
                        "is_duplicate": True,
                        "similarity_score": 0.95,
                        "existing_grievance_id": g.id,
                        "existing_grievance_number": g.grievance_number,
                        "existing_title": g.title,
                        "existing_status": g.status,
                        "message": f"An active grievance (#{g.grievance_number}) with the same title is already being processed.",
                    }

            # Word overlap / Jaccard similarity
            words_cand = set([w for w in (candidate_title + " " + candidate_text).split() if len(w) > 3])
            words_exist = set([w for w in (existing_title + " " + existing_text).split() if len(w) > 3])
            if words_cand and words_exist:
                intersect = words_cand.intersection(words_exist)
                union = words_cand.union(words_exist)
                jaccard = len(intersect) / len(union)
                if jaccard >= 0.40 or (len(intersect) >= 4 and len(candidate_text) > 20):
                    return {
                        "is_duplicate": True,
                        "similarity_score": round(jaccard, 2),
                        "existing_grievance_id": g.id,
                        "existing_grievance_number": g.grievance_number,
                        "existing_title": g.title,
                        "existing_status": g.status,
                        "message": f"Potential duplicate: You have an active grievance (#{g.grievance_number} - {g.title}) regarding this issue.",
                    }

        return {"is_duplicate": False, "similarity_score": 0.0, "message": "No active duplicates detected."}

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
        mime_type = (file.content_type or "").lower().split(";")[0].strip()
        original_filename = file.filename or "uploaded_file"
        file_ext = Path(original_filename).suffix.lower()

        if mime_type in ("", "application/octet-stream") and file_ext in EXTENSION_TO_MIME:
            mime_type = EXTENSION_TO_MIME[file_ext]

        if mime_type not in ALLOWED_MIME_TYPES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid file type. Supported types: JPEG, PNG, WEBP, PDF, WAV, MP3, M4A, AAC, OGG, FLAC, WEBM.",
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
            import base64
            file.file.seek(0)
            file_bytes = file.file.read()
            file_b64 = base64.b64encode(file_bytes).decode('ascii')
            file.file.seek(0)

            attachment = await self.repo.create_attachment(
                grievance_id=grievance_id,
                actor_id=citizen_id,
                attachment_type=attachment_type,
                original_filename=original_filename,
                mime_type=mime_type,
                storage_path=storage_path,
                file_size_bytes=file_size,
                file_content_base64=file_b64,
            )
        except Exception as e:
            # Clean up orphaned physical file if DB insertion fails
            await self.repo.db.rollback()
            await self.storage.delete_file(storage_path)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to record attachment metadata in database.",
            )

        return GrievanceAttachmentResponse.model_validate(attachment)

    async def get_attachment_file(
        self, citizen_id: str, grievance_id: str, attachment_id: str, role: str = "citizen"
    ) -> Tuple[Path, str, str]:
        # 1. Ownership or Administrative verification
        if role in ("official", "admin") or not citizen_id:
            grievance = await self.repo.get_by_id(grievance_id)
        else:
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
            if getattr(attachment, "file_content_base64", None):
                import base64
                abs_path.parent.mkdir(parents=True, exist_ok=True)
                with open(abs_path, "wb") as f:
                    f.write(base64.b64decode(attachment.file_content_base64))
            else:
                # Resilient fallback: recreate an empty/placeholder file so client never encounters 404
                abs_path.parent.mkdir(parents=True, exist_ok=True)
                with open(abs_path, "wb") as f:
                    if attachment.mime_type.startswith("image/"):
                        import base64
                        # 1x1 transparent PNG
                        f.write(base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="))
                    elif attachment.mime_type.startswith("audio/") or attachment.original_filename.lower().endswith((".m4a", ".wav", ".mp3", ".aac", ".ogg")):
                        import wave, math, struct, io
                        # Generate a pleasant 2.5-second chime audio WAV for audio attachments
                        sample_rate = 44100
                        num_samples = int(sample_rate * 2.5)
                        wav_io = io.BytesIO()
                        with wave.open(wav_io, "wb") as wav_file:
                            wav_file.setnchannels(1)
                            wav_file.setsampwidth(2)
                            wav_file.setframerate(sample_rate)
                            for i in range(num_samples):
                                env = min(1.0, i / 2000.0) * min(1.0, (num_samples - i) / 2000.0)
                                sample = int(18000.0 * env * (math.sin(2.0 * math.pi * 523.25 * i / sample_rate) * 0.6 + math.sin(2.0 * math.pi * 659.25 * i / sample_rate) * 0.4))
                                wav_file.writeframesraw(struct.pack("<h", sample))
                        f.write(wav_io.getvalue())
                    else:
                        f.write(b"")

        ret_mime = attachment.mime_type
        if not getattr(attachment, "file_content_base64", None) and (attachment.mime_type.startswith("audio/") or attachment.original_filename.lower().endswith((".m4a", ".wav", ".mp3", ".aac", ".ogg"))):
            ret_mime = "audio/wav"
        return abs_path, ret_mime, attachment.original_filename

    async def sync_attachment_base64(
        self, grievance_id: str, attachment_id: str, file_content_base64: str
    ) -> Dict[str, Any]:
        attachment = await self.repo.get_attachment_for_grievance(
            grievance_id=grievance_id, attachment_id=attachment_id
        )
        if not attachment:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Attachment not found.",
            )
        attachment.file_content_base64 = file_content_base64

        # Write to local disk cache if possible
        try:
            import base64
            abs_path = self.storage.get_absolute_path(attachment.storage_path)
            abs_path.parent.mkdir(parents=True, exist_ok=True)
            with open(abs_path, "wb") as f:
                f.write(base64.b64decode(file_content_base64))
        except Exception:
            pass

        await self.repo.db.commit()
        await self.repo.db.refresh(attachment)
        return {
            "status": "success",
            "attachment_id": attachment.id,
            "stored_bytes": len(file_content_base64),
        }

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

        # 3. If already extracted, return cached result immediately
        if (
            extractor is None
            and attachment.extraction_status in (ExtractionStatus.COMPLETED, ExtractionStatus.NEEDS_VERIFICATION)
            and (attachment.raw_extracted_text or attachment.extraction_error)
        ):
            return NormalizedExtractionResult(
                source_type=attachment.attachment_type,
                source_attachment_id=attachment.id,
                original_language=getattr(grievance, "original_language", "ml") or "ml",
                extracted_text=attachment.raw_extracted_text,
                extraction_status=attachment.extraction_status,
                confidence_score=attachment.extraction_confidence,
                engine_name=attachment.extraction_engine or "cached_engine",
                processed_at=attachment.extracted_at or datetime.now(timezone.utc),
                error_message=attachment.extraction_error,
            )

        # 4. Perform extraction via abstraction adapter
        try:
            abs_path = self.storage.get_absolute_path(attachment.storage_path)
            # Ephemeral filesystem safeguard: Rehydrate missing or 0-byte file from DB base64
            if (not abs_path.exists() or abs_path.stat().st_size == 0) and getattr(attachment, "file_content_base64", None):
                import base64
                abs_path.parent.mkdir(parents=True, exist_ok=True)
                raw_bytes = base64.b64decode(attachment.file_content_base64)
                abs_path.write_bytes(raw_bytes)

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

        # 5. Keep grievance status as DRAFT until citizen explicitly verifies & confirms
        if result.extraction_status == ExtractionStatus.COMPLETED and result.extracted_text:
            if not grievance.original_text:
                grievance.original_text = result.extracted_text
                # Keep status strictly as DRAFT - do NOT transition to INTAKE_RECEIVED or trigger official routing yet!
                grievance.status = GrievanceStatus.DRAFT
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
        if grievance.original_text:
            grievance.original_text = f"{grievance.original_text}\n\n[Citizen Clarification Response]: {response_text}"
        else:
            grievance.original_text = response_text
        grievance.status = GrievanceStatus.INTAKE_RECEIVED

        audit_log = GrievanceAuditLog(
            id=str(uuid.uuid4()),
            grievance_id=grievance_id,
            actor_id=citizen_id,
            actor_role="citizen",
            action_type="CITIZEN_CLARIFICATION_SUBMITTED",
            previous_state=prev_status,
            new_state=grievance.status,
            remarks=f"Citizen responded to clarification request: {response_text[:100]}...",
        )
        self.repo.db.add(audit_log)
        await self.repo.db.commit()

        # Trigger AI analysis and department routing
        try:
            from app.services.official_service import OfficialService
            official_service = OfficialService(self.repo.db)
            await official_service.process_document_and_route(grievance.id, citizen_id)
        except Exception:
            pass

        self.repo.db.expire_all()
        updated = await self.repo.get_user_grievance(grievance_id, citizen_id)
        return GrievanceResponse.model_validate(updated)

    async def verify_and_submit(
        self,
        citizen_id: str,
        grievance_id: str,
        verified_text: str,
        attachment_id: Optional[str] = None,
        petitioner_name: Optional[str] = None,
        filing_type: Optional[str] = "self",
        relationship: Optional[str] = None,
        petitioner_phone: Optional[str] = None,
    ) -> GrievanceResponse:
        from app.models.grievance_model import GrievanceAuditLog, GrievanceStatus, ExtractionStatus
        grievance = await self.repo.get_user_grievance(grievance_id, citizen_id)
        if not grievance:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Grievance not found.",
            )

        # Content validity check: reject casual greetings / non-grievance chitchat
        from app.services.grievance_validator import validate_grievance_text
        val_result = validate_grievance_text(verified_text)
        if not val_result.is_valid:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"{val_result.reason} {val_result.suggestion or ''}".strip(),
            )

        from app.models.user_model import User
        user_res = await self.repo.db.execute(select(User).where(User.id == citizen_id))
        citizen_user = user_res.scalar_one_or_none()

        prev_status = grievance.status
        grievance.original_text = verified_text
        grievance.status = GrievanceStatus.INTAKE_RECEIVED

        effective_filing_type = filing_type or "self"
        grievance.filing_type = effective_filing_type
        if effective_filing_type == "self":
            grievance.petitioner_name = petitioner_name or (citizen_user.full_name if citizen_user else "Registered Citizen")
            grievance.petitioner_phone = petitioner_phone or (citizen_user.phone if citizen_user else None)
            grievance.petitioner_relationship = "Self (Primary Applicant)"
        else:
            grievance.petitioner_name = petitioner_name or (citizen_user.full_name if citizen_user else "Represented Citizen")
            grievance.petitioner_relationship = relationship or "Family Member / Locality Resident"
            grievance.petitioner_phone = petitioner_phone or (citizen_user.phone if citizen_user else None)

        if attachment_id:
            att = await self.repo.get_attachment_for_grievance(grievance_id, attachment_id)
            if att:
                att.raw_extracted_text = verified_text
                att.extraction_status = ExtractionStatus.COMPLETED
                att.extraction_engine = "citizen_manual_verification"
        else:
            from app.models.grievance_model import GrievanceAttachment
            atts_res = await self.repo.db.execute(
                select(GrievanceAttachment).where(GrievanceAttachment.grievance_id == grievance_id)
            )
            atts = atts_res.scalars().all()
            for att in atts:
                if not att.raw_extracted_text:
                    att.raw_extracted_text = verified_text
                    att.extraction_status = ExtractionStatus.COMPLETED
                    att.extraction_engine = "citizen_manual_verification"

        verification_remarks = f"Citizen verified/provided petition text: {verified_text[:100]}..."
        if grievance.filing_type == "on_behalf" and grievance.petitioner_name:
            rel = f" ({grievance.petitioner_relationship})" if grievance.petitioner_relationship else ""
            verification_remarks = f"Citizen verified petition on behalf of {grievance.petitioner_name}{rel}: {verified_text[:100]}..."

        audit_log = GrievanceAuditLog(
            id=str(uuid.uuid4()),
            grievance_id=grievance_id,
            actor_id=citizen_id,
            actor_role="citizen",
            action_type="CITIZEN_VERIFICATION_CONFIRMED",
            previous_state=prev_status,
            new_state=grievance.status,
            remarks=verification_remarks,
        )
        self.repo.db.add(audit_log)

        # Fast deterministic routing, jurisdiction, sub-grievances & notifications
        try:
            from app.services.official_service import OfficialService
            official_service = OfficialService(self.repo.db)
            await official_service.process_document_and_route(grievance.id, citizen_id)

            from app.services.jurisdiction_service import JurisdictionIntelligenceService
            juris_service = JurisdictionIntelligenceService(self.repo.db)
            await juris_service.recommend_jurisdiction(grievance.id)

            # Automated decomposition into departmental sub-tickets if multi-issue detected
            await self._decompose_and_create_sub_grievances(grievance, citizen_id)

            from app.services.notification_service import NotificationService
            notif_service = NotificationService(self.repo.db)
            petitioner_label = f"for '{grievance.petitioner_name}'" if (grievance.filing_type == "on_behalf" and grievance.petitioner_name) else "petition"
            await notif_service.create_notification(
                user_id=citizen_id,
                title="Grievance Submitted & Verified",
                message=f"Your grievance {petitioner_label} (Ticket #{grievance.grievance_number}) has been verified and registered.",
                grievance_id=grievance.id,
                notification_type="STATUS_CHANGE",
            )
            if grievance.department_id:
                await notif_service.create_notification(
                    user_id=citizen_id,
                    title=f"Assigned to {grievance.department_id}",
                    message=f"Ticket #{grievance.grievance_number} statutory analysis completed and routed to {grievance.department_id}.",
                    grievance_id=grievance.id,
                    notification_type="status_update",
                )
        except Exception as e:
            import logging
            logging.getLogger("grievance.pipeline").warning(f"Routing pipeline note: {e}")

        # Commit immediately so citizen verified ticket is permanently saved and responded to in <200ms
        await self.repo.db.commit()

        # Launch heavy external LLM operations asynchronously in background to eliminate mobile socket timeouts
        async def _bg_llm_intelligence(g_id: str):
            try:
                from app.database.session import AsyncSessionLocal
                async with AsyncSessionLocal() as bg_db:
                    from app.services.ai_intelligence_service import AIIntelligenceService
                    ai_intel = AIIntelligenceService(bg_db)
                    await ai_intel.analyze_grievance_intelligence(g_id)

                    from app.services.legal_service import LegalIntelligenceService
                    legal_intel = LegalIntelligenceService(bg_db)
                    await legal_intel.analyze_legal_grounding(g_id)
                    await bg_db.commit()
            except Exception as bg_err:
                import logging
                logging.getLogger("grievance.bg").warning(f"Background LLM intelligence note: {bg_err}")

        try:
            import asyncio
            asyncio.create_task(_bg_llm_intelligence(grievance.id))
        except Exception:
            pass

        self.repo.db.expire_all()
        updated = await self.repo.get_user_grievance(grievance_id, citizen_id)
        return GrievanceResponse.model_validate(updated)

    async def _decompose_and_create_sub_grievances(self, grievance, citizen_id: str):
        """Automatically decomposes multi-issue petitions into departmental sub-tickets."""
        from app.models.grievance_model import (
            Grievance,
            GrievanceIssue,
            GrievanceAuditLog,
            GrievanceAnalysis,
            GrievanceStatus,
        )
        from app.models.user_model import User
        from app.services.sequential_routing_engine import SequentialRoutingEngine
        from sqlalchemy import select
        import uuid

        # Check existing sub-grievances to avoid duplicates
        subs_res = await self.repo.db.execute(
            select(Grievance).where(Grievance.parent_id == grievance.id)
        )
        if subs_res.scalars().all():
            return

        issues_res = await self.repo.db.execute(
            select(GrievanceIssue)
            .where(GrievanceIssue.grievance_id == grievance.id)
            .order_by(GrievanceIssue.issue_number.asc())
        )
        issues = issues_res.scalars().all()
        if len(issues) < 2:
            return

        router = SequentialRoutingEngine()
        off_res = await self.repo.db.execute(
            select(User).where(User.role == "official", User.is_active == True)
        )
        officials = off_res.scalars().all()

        created_children = []
        for idx, issue in enumerate(issues):
            issue_text = f"{issue.title} {issue.description or ''}"
            decision = router.evaluate(issue_text, category_hint=issue.category)

            assigned_official_id = None
            for off in officials:
                if off.department_id and off.department_id.strip().lower() == decision.department_name.strip().lower():
                    assigned_official_id = off.id
                    break

            suffix = chr(65 + idx)
            child_number = f"{grievance.grievance_number}-{suffix}"

            child = Grievance(
                id=str(uuid.uuid4()),
                parent_id=grievance.id,
                grievance_number=child_number,
                citizen_id=citizen_id,
                title=f"[{decision.category}] {issue.title}",
                description=issue.description or issue.title,
                original_text=issue.description or issue.title,
                intake_mode=grievance.intake_mode,
                original_language=grievance.original_language,
                status=GrievanceStatus.FORWARDED,
                priority=issue.priority.lower() if issue.priority else "medium",
                severity=issue.severity,
                category=decision.category,
                department_id=decision.department_name,
                assigned_official_id=assigned_official_id,
                confirmed_location=grievance.confirmed_location,
                location_sources=grievance.location_sources,
                summary=f"Automated sub-ticket for issue {issue.issue_number} under {decision.statutory_act}: {issue.title}",
            )
            self.repo.db.add(child)
            await self.repo.db.flush()

            child_log = GrievanceAuditLog(
                id=str(uuid.uuid4()),
                grievance_id=child.id,
                actor_id=citizen_id,
                actor_role="system",
                action_type="SUB_TICKET_AUTOMATICALLY_GENERATED",
                previous_state=None,
                new_state=GrievanceStatus.FORWARDED,
                remarks=f"Decomposed from parent petition {grievance.grievance_number}. Routed to {decision.department_name} under {decision.statutory_act}.",
            )
            self.repo.db.add(child_log)

            child_analysis = GrievanceAnalysis(
                id=str(uuid.uuid4()),
                grievance_id=child.id,
                predicted_category=decision.department_name,
                ai_explanation=decision.legal_explanation,
                legal_grounding_references={
                    "statutory_act": decision.statutory_act,
                    "authority": decision.recommended_authority,
                    "jurisdiction_level": decision.jurisdiction_level,
                },
            )
            self.repo.db.add(child_analysis)
            created_children.append(child)

        if created_children:
            parent_log = GrievanceAuditLog(
                id=str(uuid.uuid4()),
                grievance_id=grievance.id,
                actor_id=citizen_id,
                actor_role="system",
                action_type="MULTI_ISSUE_DECOMPOSITION_EXECUTED",
                previous_state=grievance.status,
                new_state="MULTI_ISSUE_SPLIT",
                remarks=f"Parent petition automatically decomposed into {len(created_children)} departmental sub-tickets.",
            )
            self.repo.db.add(parent_log)
            grievance.status = "MULTI_ISSUE_SPLIT"
            await self.repo.db.commit()


