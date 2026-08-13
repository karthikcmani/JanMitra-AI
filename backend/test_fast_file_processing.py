import asyncio
import sys
from pathlib import Path
from app.models.grievance_model import GrievanceAttachment, AttachmentType
from app.services.extraction_service import FastAutoExtractionAdapter

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

async def test_fast_processing():
    print("=" * 65)
    print("JanMitra AI — Fast Uploaded File OCR & Intelligence Processing")
    print("=" * 65)

    sample_dir = Path("sample_files")
    sample_dir.mkdir(exist_ok=True)
    sample_file = sample_dir / "sample_petition.txt"
    sample_file.write_text("വാർഡ് 5 ൽ കുടിവെള്ള വിതരണം തടസ്സപ്പെട്ടു. റോഡ് പണി ഉടൻ പൂർത്തിയാക്കണം.", encoding="utf-8")

    attachment = GrievanceAttachment(
        id="test-att-101",
        grievance_id="test-grv-101",
        attachment_type=AttachmentType.HANDWRITTEN_PETITION,
        original_filename=sample_file.name,
        mime_type="text/plain",
        storage_path=str(sample_file),
    )

    extractor = FastAutoExtractionAdapter()
    print(f"\n[INITIATING FAST FILE EXTRACTION] File: {sample_file.name}")
    result = await extractor.extract_content(attachment, file_path=sample_file)

    print("\n--- FAST PROCESSING RESULT ---")
    print(f"Status           : {result.extraction_status}")
    print(f"Engine Used      : {result.engine_name}")
    print(f"Confidence Score : {result.confidence_score}")
    print(f"Language         : {result.original_language}")
    print(f"Processed At     : {result.processed_at}")
    
    if result.extracted_text:
        print("\n--- EXTRACTED TEXT OUTPUT ---")
        print(result.extracted_text)
        print("=" * 65)

if __name__ == "__main__":
    asyncio.run(test_fast_processing())
