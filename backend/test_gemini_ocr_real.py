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

    assert result.extraction_status == ExtractionStatus.NEEDS_VERIFICATION
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


@pytest.mark.asyncio
async def test_gemini_429_needs_verification_and_manual_entry_flow(tmp_path):
    import time
    from datetime import datetime, timezone
    from httpx import ASGITransport, AsyncClient
    from app.main import app
    from sqlalchemy import select
    from app.database.session import AsyncSessionLocal
    from app.models.grievance_model import ExtractionStatus, GrievanceAttachment, GrievanceAuditLog
    from app.services.extraction_service import NormalizedExtractionResult

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # 1. Register & Login Citizen
        email = f"quota_test_{int(time.time())}@gov.in"
        password = "Password123!"
        reg = await client.post(
            "/api/v1/auth/register",
            json={
                "full_name": "Quota Test Citizen",
                "email": email,
                "phone": "9876500000",
                "password": password,
                "role": "citizen",
            },
        )
        assert reg.status_code == 201
        login_res = await client.post(
            "/api/v1/auth/login",
            json={"email": email, "password": password},
        )
        assert login_res.status_code == 200
        token = login_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # 2. Create Draft
        draft_res = await client.post(
            "/api/v1/grievances/intake/draft",
            json={"title": "Handwritten Petition 429 Test"},
            headers=headers,
        )
        grievance_id = draft_res.json()["id"]

        # 3. Upload Attachment
        test_img = tmp_path / "petition_429.jpg"
        test_img.write_bytes(b"\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00")

        # Mock Gemini returning NEEDS_VERIFICATION (e.g. Quota Limit HTTP 429)
        mock_result = NormalizedExtractionResult(
            source_type="handwritten_petition",
            source_attachment_id="fake_att",
            original_language="ml",
            extracted_text=None,
            extraction_status=ExtractionStatus.NEEDS_VERIFICATION,
            confidence_score=None,
            engine_name="gemini_vision_ocr_v1",
            processed_at=datetime.now(timezone.utc),
            error_message="Automatic text extraction is temporarily unavailable. Please enter or verify the complaint text manually.",
        )

        with patch("app.services.extraction_service.FastAutoExtractionAdapter.extract_content", new_callable=AsyncMock, return_value=mock_result):
            upload_res = await client.post(
                f"/api/v1/grievances/{grievance_id}/attachments",
                files={"file": ("petition_429.jpg", open(test_img, "rb"), "image/jpeg")},
                headers=headers,
            )

        assert upload_res.status_code == 201
        att_data = upload_res.json()
        assert att_data["extraction_status"] == "needs_verification"
        assert att_data["raw_extracted_text"] is None
        assert "temporarily unavailable" in att_data["extraction_error"]

        # 4. Citizen verifies/transcribes text manually
        verified_text = "ഞങ്ങളുടെ ഗ്രാമത്തിൽ കുടിവെള്ള പൈപ്പ് പൊട്ടി വെള്ളം പാഴാകുന്നു. അടിയന്തരമായി കെ.ഡബ്ല്യു.എ. പരിഹരിക്കണം."
        verify_res = await client.post(
            f"/api/v1/grievances/{grievance_id}/verify",
            json={"verified_text": verified_text, "attachment_id": att_data["id"]},
            headers=headers,
        )

        assert verify_res.status_code == 200
        v_data = verify_res.json()
        assert v_data["status"] in ("intake_received", "under_analysis", "forwarded", "under_processing")
        assert v_data["original_text"] == verified_text
        assert v_data["category"] is not None
        assert v_data["department_id"] is not None

        # 5. Verify PostgreSQL Audit Log & Attachment Update
        async with AsyncSessionLocal() as db:
            att_db = (
                await db.execute(
                    select(GrievanceAttachment).where(GrievanceAttachment.id == att_data["id"])
                )
            ).scalar_one_or_none()
            assert att_db.extraction_status == "completed"
            assert att_db.raw_extracted_text == verified_text
            assert att_db.extraction_engine == "citizen_manual_verification"

            audit_log = (
                await db.execute(
                    select(GrievanceAuditLog).where(
                        GrievanceAuditLog.grievance_id == grievance_id,
                        GrievanceAuditLog.action_type == "CITIZEN_VERIFICATION_CONFIRMED",
                    )
                )
            ).scalar_one_or_none()
            assert audit_log is not None
