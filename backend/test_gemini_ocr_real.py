import asyncio
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch
import pytest
from app.models.grievance_model import GrievanceAttachment
from app.services.extraction_service import GeminiVisionOCRAdapter, ExtractionStatus
from app.ai.gemini_service import GeminiGrievanceAnalyzer


@pytest.mark.asyncio
async def test_gemini_ocr_adapter_missing_key(tmp_path):
    test_img = tmp_path / "test.jpg"
    test_img.write_bytes(b"fake image bytes")

    attachment = GrievanceAttachment(
        id="att-001",
        grievance_id="grv-001",
        attachment_type="handwritten_petition",
        original_filename="test.jpg",
        mime_type="image/jpeg",
        storage_path=str(test_img),
    )

    adapter = GeminiVisionOCRAdapter()
    with patch("app.services.extraction_service.get_gemini_api_key", return_value=None):
        result = await adapter.extract_content(attachment, file_path=test_img)

    assert result.extraction_status == ExtractionStatus.FAILED
    assert "GEMINI_API_KEY NOT AVAILABLE" in result.error_message


@pytest.mark.asyncio
async def test_gemini_ocr_adapter_image_mocked_success(tmp_path):
    test_img = tmp_path / "malayalam_petition.png"
    test_img.write_bytes(b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82")

    attachment = GrievanceAttachment(
        id="att-002",
        grievance_id="grv-002",
        attachment_type="handwritten_petition",
        original_filename="malayalam_petition.png",
        mime_type="image/png",
        storage_path=str(test_img),
    )

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "candidates": [
            {
                "content": {
                    "parts": [
                        {
                            "text": "വാർഡ് 4 കുടിവെള്ള പ്രശ്നം പരിഹരിക്കണം.\n--- EXTRACTED KEYWORDS & SUMMARY ---\nSubject: Water Supply"
                        }
                    ]
                }
            }
        ]
    }

    adapter = GeminiVisionOCRAdapter()
    with patch("app.services.extraction_service.get_gemini_api_key", return_value="TEST_SAFE_KEY_123"):
        with patch("httpx.AsyncClient.post", new_callable=AsyncMock, return_value=mock_resp):
            result = await adapter.extract_content(attachment, file_path=test_img)

    assert result.extraction_status == ExtractionStatus.COMPLETED
    assert "വാർഡ് 4 കുടിവെള്ള പ്രശ്നം" in result.extracted_text
    assert "gemini_vision_ocr_" in result.engine_name


@pytest.mark.asyncio
async def test_gemini_ocr_adapter_pdf_rendering_success(tmp_path):
    test_pdf = tmp_path / "petition_document.pdf"
    test_pdf.write_bytes(b"%PDF-1.4\n%%EOF")

    attachment = GrievanceAttachment(
        id="att-003",
        grievance_id="grv-003",
        attachment_type="scanned_document",
        original_filename="petition_document.pdf",
        mime_type="application/pdf",
        storage_path=str(test_pdf),
    )

    mock_pix = MagicMock()
    mock_pix.tobytes.return_value = b"png_bytes_from_pdf"
    mock_page = MagicMock()
    mock_page.get_pixmap.return_value = mock_pix
    mock_doc = [mock_page]
    mock_fitz = MagicMock()
    mock_fitz.open.return_value = MagicMock(__iter__=lambda self: iter(mock_doc), close=lambda: None)

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "candidates": [
            {
                "content": {
                    "parts": [
                        {"text": "പേജ് 1: പഞ്ചായത്ത് റോഡ് അറ്റകുറ്റപ്പണി നടത്തണം."}
                    ]
                }
            }
        ]
    }

    adapter = GeminiVisionOCRAdapter()
    with patch("app.services.extraction_service.get_gemini_api_key", return_value="TEST_SAFE_KEY_123"):
        with patch("app.services.extraction_service.fitz", mock_fitz):
            with patch("httpx.AsyncClient.post", new_callable=AsyncMock, return_value=mock_resp):
                result = await adapter.extract_content(attachment, file_path=test_pdf)

    assert result.extraction_status == ExtractionStatus.COMPLETED
    assert "പഞ്ചായത്ത് റോഡ് അറ്റകുറ്റപ്പണി" in result.extracted_text


@pytest.mark.asyncio
async def test_gemini_ocr_adapter_safe_error_logging_no_secret_leak(tmp_path):
    test_img = tmp_path / "test.jpg"
    test_img.write_bytes(b"dummy image bytes")

    attachment = GrievanceAttachment(
        id="att-004",
        grievance_id="grv-004",
        attachment_type="handwritten_petition",
        original_filename="test.jpg",
        mime_type="image/jpeg",
        storage_path=str(test_img),
    )

    mock_resp = MagicMock()
    mock_resp.status_code = 400
    mock_resp.text = "INVALID_ARGUMENT: Invalid image data for key SUPER_SECRET_KEY_12345"

    adapter = GeminiVisionOCRAdapter()
    with patch("app.services.extraction_service.get_gemini_api_key", return_value="SUPER_SECRET_KEY_12345"):
        with patch("httpx.AsyncClient.post", new_callable=AsyncMock, return_value=mock_resp):
            result = await adapter.extract_content(attachment, file_path=test_img)

    assert result.extraction_status == ExtractionStatus.FAILED
    assert "SUPER_SECRET_KEY_12345" not in result.error_message
    assert "[REDACTED]" in result.error_message or "400" in result.error_message


@pytest.mark.asyncio
async def test_gemini_grievance_analyzer():
    analyzer = GeminiGrievanceAnalyzer(api_key="TEST_KEY")

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {
        "candidates": [
            {
                "content": {
                    "parts": [
                        {
                            "text": '{"category": "Water Supply & Drainage", "department_name": "Kerala Water Authority (KWA)", "summary": "Pipe leakage issue", "key_entities": ["Ward 5", "KWA"], "priority": "high", "statutory_reference": "Kerala Water Supply Act", "reasoning": "Direct water supply issue", "confidence_score": 0.95}'
                        }
                    ]
                }
            }
        ]
    }

    with patch("httpx.AsyncClient.post", new_callable=AsyncMock, return_value=mock_resp):
        res = await analyzer.analyze_grievance("വാർഡ് 5 ൽ കുടിവെള്ള പൈപ്പ് പൊട്ടിയിരിക്കുന്നു")

    assert res is not None
    assert res.category == "Water Supply & Drainage"
    assert res.department_name == "Kerala Water Authority (KWA)"
    assert res.confidence_score == 0.95


@pytest.mark.asyncio
async def test_gemini_ocr_adapter_never_selects_gemini_2_5_flash():
    import inspect
    from app.services.extraction_service import GeminiVisionOCRAdapter
    from app.ai.gemini_service import GeminiGrievanceAnalyzer

    source_ext = inspect.getsource(GeminiVisionOCRAdapter)
    source_ai = inspect.getsource(GeminiGrievanceAnalyzer)

    assert "gemini-2.5-flash" not in source_ext, "gemini-2.5-flash must not be present in extraction_service.py"
    assert "gemini-2.5-flash" not in source_ai, "gemini-2.5-flash must not be present in gemini_service.py"

