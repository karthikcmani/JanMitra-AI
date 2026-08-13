import asyncio
from pathlib import Path
from unittest.mock import MagicMock, patch
import pytest
from app.models.grievance_model import GrievanceAttachment
from app.services.extraction_service import CloudVisionMalayalamOCR, ExtractionStatus


@pytest.mark.asyncio
async def test_cloud_vision_ocr_missing_credentials(tmp_path):
    # Setup test file
    test_file = tmp_path / "test_petition.jpg"
    test_file.write_bytes(b"dummy image bytes")

    attachment = GrievanceAttachment(
        id="att-123",
        grievance_id="grv-123",
        attachment_type="handwritten_petition",
        original_filename="test_petition.jpg",
        mime_type="image/jpeg",
        storage_path=str(test_file),
    )

    # Initialize adapter with non-existent credentials path
    adapter = CloudVisionMalayalamOCR(credentials_path="/non/existent/creds.json")
    result = await adapter.extract_content(attachment, file_path=test_file)

    assert result.extraction_status == ExtractionStatus.FAILED
    assert result.engine_name == "google_cloud_vision_v1"
    assert "credentials" in result.error_message.lower()
    # File on disk remains unchanged
    assert test_file.exists()
    assert test_file.read_bytes() == b"dummy image bytes"


@pytest.mark.asyncio
async def test_cloud_vision_ocr_mocked_image_extraction(tmp_path):
    test_file = tmp_path / "handwritten_sample.png"
    test_file.write_bytes(b"png content")

    attachment = GrievanceAttachment(
        id="att-456",
        grievance_id="grv-456",
        attachment_type="handwritten_petition",
        original_filename="handwritten_sample.png",
        mime_type="image/png",
        storage_path=str(test_file),
    )

    # Mock Vision API Client response
    mock_word = MagicMock()
    mock_word.confidence = 0.895

    mock_paragraph = MagicMock()
    mock_paragraph.words = [mock_word]

    mock_block = MagicMock()
    mock_block.paragraphs = [mock_paragraph]

    mock_page = MagicMock()
    mock_page.blocks = [mock_block]

    mock_annotation = MagicMock()
    mock_annotation.text = "വാർഡ് 5 കുടിവെള്ള പ്രശ്നം"
    mock_annotation.pages = [mock_page]

    mock_response = MagicMock()
    mock_response.error.message = ""
    mock_response.full_text_annotation = mock_annotation

    mock_client = MagicMock()
    mock_client.document_text_detection.return_value = mock_response

    adapter = CloudVisionMalayalamOCR()
    with patch.object(adapter, "_get_vision_client", return_value=mock_client):
        result = await adapter.extract_content(attachment, file_path=test_file)

    assert result.extraction_status == ExtractionStatus.COMPLETED
    assert result.engine_name == "google_cloud_vision_v1"
    assert result.extracted_text == "വാർഡ് 5 കുടിവെള്ള പ്രശ്നം"
    assert result.confidence_score == 0.895
    assert test_file.read_bytes() == b"png content"


@pytest.mark.asyncio
async def test_cloud_vision_ocr_mocked_pdf_extraction(tmp_path):
    test_pdf = tmp_path / "multi_page_petition.pdf"
    test_pdf.write_bytes(b"%PDF-1.4\n%%EOF")

    attachment = GrievanceAttachment(
        id="att-789",
        grievance_id="grv-789",
        attachment_type="handwritten_petition",
        original_filename="multi_page_petition.pdf",
        mime_type="application/pdf",
        storage_path=str(test_pdf),
    )

    mock_annotation = MagicMock()
    mock_annotation.text = "പേജ് 1: ഹർജി വിവരങ്ങൾ"
    mock_annotation.pages = []

    mock_response = MagicMock()
    mock_response.error.message = ""
    mock_response.full_text_annotation = mock_annotation

    mock_client = MagicMock()
    mock_client.document_text_detection.return_value = mock_response

    # Mock PyMuPDF fitz rendering
    mock_pix = MagicMock()
    mock_pix.tobytes.return_value = b"rendered_png"
    mock_page = MagicMock()
    mock_page.get_pixmap.return_value = mock_pix
    mock_doc = [mock_page]

    adapter = CloudVisionMalayalamOCR()
    with patch.object(adapter, "_get_vision_client", return_value=mock_client):
        with patch("fitz.open", return_value=MagicMock(__iter__=lambda self: iter(mock_doc), close=lambda: None)):
            result = await adapter.extract_content(attachment, file_path=test_pdf)

    assert result.extraction_status == ExtractionStatus.COMPLETED
    assert result.extracted_text == "പേജ് 1: ഹർജി വിവരങ്ങൾ"
    assert test_pdf.read_bytes() == b"%PDF-1.4\n%%EOF"


if __name__ == "__main__":
    asyncio.run(test_cloud_vision_ocr_missing_credentials(Path(".")))
