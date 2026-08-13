import asyncio
import os
import sys
from pathlib import Path
from app.models.grievance_model import GrievanceAttachment
from app.services.extraction_service import CloudVisionMalayalamOCR


async def main():
    print("=" * 60)
    print("JanMitra AI — Real Malayalam OCR Verification Script")
    print("=" * 60)

    if len(sys.argv) < 2:
        print("\nUsage:")
        print("  python run_real_malayalam_ocr.py <path_to_malayalam_sample_image_or_pdf>")
        print("\nExample:")
        print("  python run_real_malayalam_ocr.py sample_petition.jpg")
        return

    sample_path = Path(sys.argv[1]).resolve()
    if not sample_path.exists():
        print(f"\n[ERROR] File not found at path: {sample_path}")
        return

    creds_env = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    if not creds_env:
        print("\n[WARNING] GOOGLE_APPLICATION_CREDENTIALS environment variable is NOT set.")
        print("Ensure you set GOOGLE_APPLICATION_CREDENTIALS=/path/to/service_account.json for live GCP testing.")

    attachment = GrievanceAttachment(
        id="sample-att-001",
        grievance_id="sample-grv-001",
        attachment_type="handwritten_petition",
        original_filename=sample_path.name,
        mime_type="application/pdf" if sample_path.suffix.lower() == ".pdf" else "image/jpeg",
        storage_path=str(sample_path),
    )

    ocr_adapter = CloudVisionMalayalamOCR()
    print(f"\nProcessing real file: {sample_path.name} ({sample_path.stat().st_size} bytes)")
    print("Engine: google_cloud_vision_v1 (DOCUMENT_TEXT_DETECTION)...")

    result = await ocr_adapter.extract_content(attachment, file_path=sample_path)

    print("\n--- OCR EXTRACTION RESULT ---")
    print(f"Status       : {result.extraction_status}")
    print(f"Engine       : {result.engine_name}")
    print(f"Confidence   : {result.confidence_score if result.confidence_score is not None else 'N/A (Not provided/derived)'}")
    print(f"Language     : {result.original_language}")
    print(f"Processed At : {result.processed_at}")

    if result.error_message:
        print(f"Error        : {result.error_message}")

    if result.extracted_text:
        print("\n--- RAW EXTRACTED MALAYALAM TEXT ---")
        print(result.extracted_text)
        print("-" * 50)
    else:
        print("\n[NOTICE] No text extracted or credential configuration required.")


if __name__ == "__main__":
    asyncio.run(main())
