import asyncio
import os
import time
from pathlib import Path
import pytest

from app.database.session import AsyncSessionLocal, init_db_schema
from app.models.grievance_model import AttachmentType, Grievance, GrievanceAttachment, GrievanceStatus, IntakeMode
from app.models.user_model import User
from app.services.voice_service import VoiceTranscriptionAdapter


@pytest.mark.asyncio
async def test_voice_intake_transcription():
    await init_db_schema()

    async with AsyncSessionLocal() as session:
        ts = int(time.time())
        cit_id = f"cit_voice_{ts}"
        session.add(User(id=cit_id, full_name="Voice User", email=f"voice_{ts}@gov.in", password_hash="pass", role="citizen"))
        await session.commit()

        # Create voice grievance
        g_id = f"g_voice_{ts}"
        grievance = Grievance(
            id=g_id,
            grievance_number=f"JM-VOICE-{ts}",
            citizen_id=cit_id,
            title="Voice Petition Recording",
            intake_mode=IntakeMode.VOICE_STT,
            status=GrievanceStatus.DRAFT,
        )
        session.add(grievance)
        await session.commit()

        # Create dummy audio file artifact for test
        audio_dir = Path("storage/test_audio")
        audio_dir.mkdir(parents=True, exist_ok=True)
        dummy_audio_file = audio_dir / f"test_petition_{ts}.wav"
        dummy_audio_file.write_bytes(b"RIFF\x24\x00\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00\x44\xac\x00\x00\x88\x58\x01\x00\x02\x00\x10\x00data\x00\x00\x00\x00")

        att_id = f"att_voice_{ts}"
        attachment = GrievanceAttachment(
            id=att_id,
            grievance_id=g_id,
            attachment_type=AttachmentType.VOICE_RECORDING,
            original_filename=dummy_audio_file.name,
            mime_type="audio/wav",
            storage_path=str(dummy_audio_file),
            file_size_bytes=len(dummy_audio_file.read_bytes()),
        )
        session.add(attachment)
        await session.commit()

        # Run Voice Transcription Adapter
        adapter = VoiceTranscriptionAdapter()
        result = await adapter.extract_content(attachment, file_path=dummy_audio_file)

        assert result.source_type == AttachmentType.VOICE_RECORDING
        assert result.extraction_status in ["completed", "needs_verification"]
        print("Voice Transcription Test Passed! Status:", result.extraction_status, "| Engine:", result.engine_name)

        # Cleanup dummy audio test file
        if dummy_audio_file.exists():
            dummy_audio_file.unlink()


if __name__ == "__main__":
    asyncio.run(test_voice_intake_transcription())
