from abc import ABC, abstractmethod
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
from pydantic import BaseModel, ConfigDict
from app.models.grievance_model import AttachmentType, ExtractionStatus, GrievanceAttachment


class NormalizedExtractionResult(BaseModel):
    source_type: str
    source_attachment_id: Optional[str] = None
    original_language: str = "ml"
    extracted_text: Optional[str] = None
    extraction_status: str
    confidence_score: Optional[float] = None
    engine_name: str
    processed_at: datetime
    error_message: Optional[str] = None

    model_config = ConfigDict(from_attributes=True)


class BaseExtractionAdapter(ABC):
    @abstractmethod
    async def extract_content(
        self, attachment: GrievanceAttachment, file_path: Optional[Path] = None
    ) -> NormalizedExtractionResult:
        """Extracts text from an intake attachment artifact."""
        pass


class MockExtractionAdapter(BaseExtractionAdapter):
    """Deterministic mock extraction adapter for Phase 1D data foundation testing.

    Does NOT call real external OCR (Tesseract/PaddleOCR) or STT (Whisper) models.
    """

    async def extract_content(
        self, attachment: GrievanceAttachment, file_path: Optional[Path] = None
    ) -> NormalizedExtractionResult:
        now = datetime.now(timezone.utc)

        # Trigger simulated failure for test cases
        if "fail_trigger" in (attachment.original_filename or "").lower():
            return NormalizedExtractionResult(
                source_type=attachment.attachment_type,
                source_attachment_id=attachment.id,
                original_language="ml",
                extracted_text=None,
                extraction_status=ExtractionStatus.FAILED,
                confidence_score=None,
                engine_name="mock_ocr_v1",
                processed_at=now,
                error_message="Simulated document OCR extraction engine failure.",
            )

        if attachment.attachment_type in [
            AttachmentType.HANDWRITTEN_PETITION,
            AttachmentType.SCANNED_DOCUMENT,
        ]:
            return NormalizedExtractionResult(
                source_type=attachment.attachment_type,
                source_attachment_id=attachment.id,
                original_language="ml",
                extracted_text="വാർഡ് 5 ൽ കുടിവെള്ള വിതരണം തടസ്സപ്പെട്ടു. റോഡ് പണി ഉടൻ പൂർത്തിയാക്കണം.",
                extraction_status=ExtractionStatus.COMPLETED,
                confidence_score=0.92,
                engine_name="mock_ocr_v1",
                processed_at=now,
            )
        elif attachment.attachment_type == AttachmentType.VOICE_RECORDING:
            return NormalizedExtractionResult(
                source_type=attachment.attachment_type,
                source_attachment_id=attachment.id,
                original_language="ml",
                extracted_text="എന്റെ പ്രദേശത്ത് കലുങ്ക് നിർമ്മാണം പാതിവഴിയിൽ നിലച്ചിരിക്കുകയാണ്.",
                extraction_status=ExtractionStatus.COMPLETED,
                confidence_score=0.88,
                engine_name="mock_stt_v1",
                processed_at=now,
            )
        elif attachment.attachment_type == AttachmentType.SUPPORTING_EVIDENCE:
            return NormalizedExtractionResult(
                source_type=attachment.attachment_type,
                source_attachment_id=attachment.id,
                original_language="en",
                extracted_text="Supporting evidence document scanned.",
                extraction_status=ExtractionStatus.COMPLETED,
                confidence_score=0.95,
                engine_name="mock_ocr_v1",
                processed_at=now,
            )
        else:
            return NormalizedExtractionResult(
                source_type=attachment.attachment_type,
                source_attachment_id=attachment.id,
                original_language="ml",
                extracted_text=None,
                extraction_status=ExtractionStatus.FAILED,
                confidence_score=None,
                engine_name="mock_adapter_v1",
                processed_at=now,
                error_message=f"Unsupported attachment type '{attachment.attachment_type}' for extraction.",
            )

    @staticmethod
    def process_direct_text(
        text: str, language: str = "ml"
    ) -> NormalizedExtractionResult:
        return NormalizedExtractionResult(
            source_type="direct_text",
            source_attachment_id=None,
            original_language=language,
            extracted_text=text,
            extraction_status=ExtractionStatus.COMPLETED,
            confidence_score=1.0,
            engine_name="direct_input",
            processed_at=datetime.now(timezone.utc),
        )
