import base64
import logging
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
import httpx

from app.models.grievance_model import AttachmentType, ExtractionStatus, GrievanceAttachment
from app.services.extraction_service import BaseExtractionAdapter, NormalizedExtractionResult, get_gemini_api_key

logger = logging.getLogger(__name__)

_whisper_model_instance = None


def get_local_whisper():
    global _whisper_model_instance
    if _whisper_model_instance is None:
        try:
            import whisper
            _whisper_model_instance = whisper.load_model("tiny")
            logger.info("Loaded local Whisper STT model ('tiny')")
        except Exception as e:
            logger.info(f"Local Whisper STT model unavailable ({e}).")
            _whisper_model_instance = "unavailable"
    return _whisper_model_instance


class VoiceTranscriptionAdapter(BaseExtractionAdapter):
    """Speech-to-Text Transcription Adapter for Malayalam & English Voice Petitions."""

    async def extract_content(
        self, attachment: GrievanceAttachment, file_path: Optional[Path] = None
    ) -> NormalizedExtractionResult:
        now = datetime.now(timezone.utc)
        engine_name = "voice_stt_adapter_v1"

        if not file_path or not file_path.exists():
            return NormalizedExtractionResult(
                source_type=attachment.attachment_type or AttachmentType.VOICE_RECORDING,
                source_attachment_id=attachment.id,
                original_language="ml",
                extracted_text=None,
                extraction_status=ExtractionStatus.FAILED,
                confidence_score=None,
                engine_name=engine_name,
                processed_at=now,
                error_message="Voice audio file path does not exist on disk.",
            )

        # 1. Try Gemini Multimodal Audio API if Gemini API Key is available
        api_key = get_gemini_api_key()
        if api_key:
            try:
                audio_bytes = file_path.read_bytes()
                encoded_b64 = base64.b64encode(audio_bytes).decode("utf-8")
                mime_type = attachment.mime_type or "audio/wav"
                if not mime_type.startswith("audio/"):
                    mime_type = "audio/wav"

                prompt = (
                    "You are an expert Speech-to-Text transcription engine for Malayalam and English public grievance audio recordings.\n"
                    "INSTRUCTIONS:\n"
                    "1. Transcribe the audio exactly as spoken in original script (Malayalam or English).\n"
                    "2. Do NOT summarize or invent missing details.\n"
                    "3. Return ONLY the transcribed text."
                )

                payload = {
                    "contents": [{
                        "parts": [
                            {"text": prompt},
                            {
                                "inline_data": {
                                    "mime_type": mime_type,
                                    "data": encoded_b64,
                                }
                            }
                        ]
                    }]
                }

                headers = {
                    "Content-Type": "application/json",
                    "x-goog-api-key": api_key.strip(),
                }

                async with httpx.AsyncClient(timeout=15.0) as client:
                    for model_name in ["gemini-3.6-flash", "gemini-3.5-flash", "gemini-flash-latest"]:
                        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent"
                        resp = await client.post(url, json=payload, headers=headers)
                        if resp.status_code == 200:
                            data = resp.json()
                            candidates = data.get("candidates", [])
                            if candidates:
                                text_parts = candidates[0].get("content", {}).get("parts", [])
                                raw_transcription = "\n".join([p.get("text", "") for p in text_parts]).strip()
                                if raw_transcription:
                                    return NormalizedExtractionResult(
                                        source_type=attachment.attachment_type,
                                        source_attachment_id=attachment.id,
                                        original_language="ml",
                                        extracted_text=raw_transcription,
                                        extraction_status=ExtractionStatus.COMPLETED,
                                        confidence_score=0.92,
                                        engine_name=f"gemini_audio_stt_{model_name.replace('-', '_')}",
                                        processed_at=now,
                                    )
            except Exception as gemini_err:
                logger.warning(f"Gemini Audio STT failed: {gemini_err}")

        # 2. Try Local Whisper Model if installed
        whisper_model = get_local_whisper()
        if whisper_model != "unavailable" and whisper_model is not None:
            try:
                res = whisper_model.transcribe(str(file_path), language="ml")
                transcribed_text = res.get("text", "").strip()
                if transcribed_text:
                    return NormalizedExtractionResult(
                        source_type=attachment.attachment_type,
                        source_attachment_id=attachment.id,
                        original_language="ml",
                        extracted_text=transcribed_text,
                        extraction_status=ExtractionStatus.COMPLETED,
                        confidence_score=0.88,
                        engine_name="whisper_local_tiny",
                        processed_at=now,
                    )
            except Exception as w_err:
                logger.warning(f"Local Whisper transcription failed: {w_err}")

        # 3. Graceful Fallback if audio STT unavailable
        return NormalizedExtractionResult(
            source_type=attachment.attachment_type,
            source_attachment_id=attachment.id,
            original_language="ml",
            extracted_text=None,
            extraction_status=ExtractionStatus.NEEDS_VERIFICATION,
            confidence_score=None,
            engine_name="voice_stt_fallback",
            processed_at=now,
            error_message="Voice transcription service is temporarily unavailable. The raw audio file is preserved. Please verify or type complaint text manually.",
        )
