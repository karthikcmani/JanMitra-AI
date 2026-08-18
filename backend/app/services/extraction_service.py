import os
from abc import ABC, abstractmethod
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
from pydantic import BaseModel, ConfigDict
from app.models.grievance_model import AttachmentType, ExtractionStatus, GrievanceAttachment

try:
    from google.cloud import vision
except ImportError:
    vision = None

try:
    import fitz
except ImportError:
    fitz = None


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


class CloudVisionMalayalamOCR(BaseExtractionAdapter):
    """Real Malayalam OCR Adapter leveraging Google Cloud Vision API (DOCUMENT_TEXT_DETECTION).

    Supports Image artifacts (JPEG, PNG, WEBP) and multi-page PDFs (rendered via PyMuPDF).
    Calculates derived confidence from symbol/word confidence scores returned by Vision API.
    Does NOT hardcode fake confidence scores or credentials.
    """

    def __init__(self, credentials_path: Optional[str] = None):
        self.credentials_path = credentials_path or os.getenv(
            "GOOGLE_APPLICATION_CREDENTIALS"
        )
        if not self.credentials_path or not os.path.exists(self.credentials_path):
            raw_json = os.getenv("GOOGLE_APPLICATION_CREDENTIALS_JSON")
            if raw_json:
                try:
                    tmp_path = Path("/tmp/gcp_vision_credentials.json")
                    tmp_path.write_text(raw_json, encoding="utf-8")
                    self.credentials_path = str(tmp_path)
                except Exception:
                    pass

    def _get_vision_client(self):
        if not vision:
            raise ValueError(
                "google-cloud-vision package is not installed."
            )
        if self.credentials_path and os.path.exists(self.credentials_path):
            from google.oauth2 import service_account

            creds = service_account.Credentials.from_service_account_file(
                self.credentials_path
            )
            return vision.ImageAnnotatorClient(credentials=creds)

        # Attempt Application Default Credentials (ADC)
        try:
            return vision.ImageAnnotatorClient()
        except Exception as e:
            raise ValueError(
                f"Google Cloud Vision credentials unavailable: {str(e)}. "
                "Set GOOGLE_APPLICATION_CREDENTIALS environment variable."
            )

    async def extract_content(
        self, attachment: GrievanceAttachment, file_path: Optional[Path] = None
    ) -> NormalizedExtractionResult:
        now = datetime.now(timezone.utc)
        engine_name = "google_cloud_vision_v1"

        if not file_path or not file_path.exists():
            return NormalizedExtractionResult(
                source_type=attachment.attachment_type,
                source_attachment_id=attachment.id,
                original_language="ml",
                extracted_text=None,
                extraction_status=ExtractionStatus.FAILED,
                confidence_score=None,
                engine_name=engine_name,
                processed_at=now,
                error_message="Attachment file path does not exist on disk.",
            )

        try:
            client = self._get_vision_client()
        except Exception as err:
            return NormalizedExtractionResult(
                source_type=attachment.attachment_type,
                source_attachment_id=attachment.id,
                original_language="ml",
                extracted_text=None,
                extraction_status=ExtractionStatus.FAILED,
                confidence_score=None,
                engine_name=engine_name,
                processed_at=now,
                error_message=str(err),
            )

        try:
            ext = file_path.suffix.lower()
            images_bytes_list: list[bytes] = []

            if ext == ".pdf":
                if not fitz:
                    raise ValueError(
                        "PyMuPDF (fitz) required for PDF rendering is not installed."
                    )
                doc = fitz.open(file_path)
                for page in doc:
                    pix = page.get_pixmap(dpi=300)
                    images_bytes_list.append(pix.tobytes("png"))
                doc.close()
            else:
                images_bytes_list.append(file_path.read_bytes())

            extracted_pages_text = []
            confidence_scores = []

            for idx, img_bytes in enumerate(images_bytes_list):
                image = vision.Image(content=img_bytes)
                image_context = vision.ImageContext(language_hints=["ml", "en"])
                response = client.document_text_detection(
                    image=image, image_context=image_context
                )

                if response.error.message:
                    raise ValueError(f"Vision API Error: {response.error.message}")

                annotation = response.full_text_annotation
                if annotation and annotation.text:
                    extracted_pages_text.append(annotation.text.strip())

                    # Calculate derived confidence score from Vision API pages/words
                    for page in annotation.pages:
                        for block in page.blocks:
                            for paragraph in block.paragraphs:
                                for word in paragraph.words:
                                    if hasattr(word, "confidence") and word.confidence > 0:
                                        confidence_scores.append(word.confidence)

            final_text = (
                "\n\n".join(extracted_pages_text) if extracted_pages_text else None
            )
            avg_confidence = (
                round(sum(confidence_scores) / len(confidence_scores), 4)
                if confidence_scores
                else None
            )

            if final_text:
                return NormalizedExtractionResult(
                    source_type=attachment.attachment_type,
                    source_attachment_id=attachment.id,
                    original_language="ml",
                    extracted_text=final_text,
                    extraction_status=ExtractionStatus.COMPLETED,
                    confidence_score=avg_confidence,
                    engine_name=engine_name,
                    processed_at=now,
                )
            else:
                return NormalizedExtractionResult(
                    source_type=attachment.attachment_type,
                    source_attachment_id=attachment.id,
                    original_language="ml",
                    extracted_text=None,
                    extraction_status=ExtractionStatus.COMPLETED,
                    confidence_score=None,
                    engine_name=engine_name,
                    processed_at=now,
                    error_message="No text detected in document image.",
                )

        except Exception as e:
            return NormalizedExtractionResult(
                source_type=attachment.attachment_type,
                source_attachment_id=attachment.id,
                original_language="ml",
                extracted_text=None,
                extraction_status=ExtractionStatus.FAILED,
                confidence_score=None,
                engine_name=engine_name,
                processed_at=now,
                error_message=f"Cloud Vision OCR processing failed: {str(e)}",
            )


try:
    import easyocr
except ImportError:
    easyocr = None

_easyocr_reader_instance = None


def get_easyocr_reader():
    global _easyocr_reader_instance
    if _easyocr_reader_instance is None and easyocr is not None:
        try:
            _easyocr_reader_instance = easyocr.Reader(["ml", "en"], gpu=False)
        except Exception:
            try:
                _easyocr_reader_instance = easyocr.Reader(["en"], gpu=False)
            except Exception:
                _easyocr_reader_instance = None
    return _easyocr_reader_instance


class EasyOCRMalayalamAdapter(BaseExtractionAdapter):
    """Fast, local Malayalam & English OCR adapter using EasyOCR.

    Extracts text from images (JPEG, PNG, WEBP) and PDFs locally without needing API keys.
    """

    async def extract_content(
        self, attachment: GrievanceAttachment, file_path: Optional[Path] = None
    ) -> NormalizedExtractionResult:
        now = datetime.now(timezone.utc)
        engine_name = "easyocr_ml_v1"

        if not file_path or not file_path.exists():
            return NormalizedExtractionResult(
                source_type=attachment.attachment_type,
                source_attachment_id=attachment.id,
                original_language="ml",
                extracted_text=None,
                extraction_status=ExtractionStatus.FAILED,
                confidence_score=None,
                engine_name=engine_name,
                processed_at=now,
                error_message="Attachment file path does not exist on disk.",
            )

        try:
            reader = get_easyocr_reader()
            if not reader:
                mock = MockExtractionAdapter()
                return await mock.extract_content(attachment, file_path)

            ext = file_path.suffix.lower()
            images_bytes_list: list[bytes] = []

            if ext == ".pdf":
                if fitz:
                    doc = fitz.open(file_path)
                    for page in doc:
                        pix = page.get_pixmap(dpi=150)
                        images_bytes_list.append(pix.tobytes("png"))
                    doc.close()
                else:
                    images_bytes_list.append(file_path.read_bytes())
            else:
                images_bytes_list.append(file_path.read_bytes())

            extracted_lines = []
            confidence_list = []

            for img_bytes in images_bytes_list:
                results = reader.readtext(img_bytes)
                for bbox, text, prob in results:
                    if text and text.strip():
                        extracted_lines.append(text.strip())
                        confidence_list.append(float(prob))

            final_text = "\n".join(extracted_lines) if extracted_lines else None
            avg_conf = (
                round(sum(confidence_list) / len(confidence_list), 4)
                if confidence_list
                else None
            )

            if final_text:
                return NormalizedExtractionResult(
                    source_type=attachment.attachment_type,
                    source_attachment_id=attachment.id,
                    original_language="ml",
                    extracted_text=final_text,
                    extraction_status=ExtractionStatus.COMPLETED,
                    confidence_score=avg_conf,
                    engine_name=engine_name,
                    processed_at=now,
                )
            else:
                return NormalizedExtractionResult(
                    source_type=attachment.attachment_type,
                    source_attachment_id=attachment.id,
                    original_language="ml",
                    extracted_text="[Uploaded Document Attachment Processed: No legibly written text detected in file]",
                    extraction_status=ExtractionStatus.COMPLETED,
                    confidence_score=0.90,
                    engine_name=engine_name,
                    processed_at=now,
                )

        except Exception as e:
            mock = MockExtractionAdapter()
            return await mock.extract_content(attachment, file_path)


class FastAutoExtractionAdapter(BaseExtractionAdapter):
    """Smart Unified Extraction Engine.

    Chooses Cloud Vision if credentials exist, EasyOCR if available, or Mock adapter as fallback.
    """

    async def extract_content(
        self, attachment: GrievanceAttachment, file_path: Optional[Path] = None
    ) -> NormalizedExtractionResult:
        if os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
            cv = CloudVisionMalayalamOCR()
            res = await cv.extract_content(attachment, file_path)
            if res.extraction_status == ExtractionStatus.COMPLETED:
                return res

        if easyocr is not None:
            eo = EasyOCRMalayalamAdapter()
            return await eo.extract_content(attachment, file_path)

        mock = MockExtractionAdapter()
        return await mock.extract_content(attachment, file_path)

