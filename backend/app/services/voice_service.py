import asyncio
import base64
import logging
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
import httpx

from app.models.grievance_model import AttachmentType, ExtractionStatus, GrievanceAttachment
from app.services.extraction_service import (
    BaseExtractionAdapter,
    NormalizedExtractionResult,
    get_gemini_api_key,
    get_groq_api_key,
    get_openai_api_key,
)

logger = logging.getLogger(__name__)

_whisper_model_instance = None

AUDIO_EXT_MIME_MAP = {
    ".wav": "audio/wav",
    ".mp3": "audio/mp3",
    ".m4a": "audio/mp4",
    ".mp4": "audio/mp4",
    ".aac": "audio/aac",
    ".ogg": "audio/ogg",
    ".opus": "audio/ogg",
    ".flac": "audio/flac",
    ".webm": "audio/webm",
}


def _normalize_audio_mime(file_path: Path, raw_mime: Optional[str]) -> str:
    ext = file_path.suffix.lower()
    if ext in AUDIO_EXT_MIME_MAP:
        return AUDIO_EXT_MIME_MAP[ext]
    if raw_mime and raw_mime.startswith("audio/"):
        if raw_mime in ("audio/x-m4a", "audio/m4a"):
            return "audio/mp4"
        if raw_mime in ("audio/x-wav", "audio/wave"):
            return "audio/wav"
        if raw_mime == "audio/mpeg":
            return "audio/mp3"
        return raw_mime
    return "audio/wav"


def get_local_whisper():
    global _whisper_model_instance
    if os.getenv("RENDER") or os.getenv("DISABLE_LOCAL_OCR") == "1":
        return "unavailable"
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
    """Multi-Engine Speech-to-Text Transcription Adapter for Malayalam & English Voice Petitions.

    Execution Priority:
    1. Groq Whisper API (whisper-large-v3-turbo / whisper-large-v3) — Ultra-fast (<2s)
    2. Google Gemini Multimodal Audio API (gemini-3.5-flash-lite / gemini-3.1-flash-lite / gemini-flash-lite-latest)
    3. OpenAI Whisper API (whisper-1)
    4. Guarded Local Whisper ('tiny' model, non-cloud only)
    5. Graceful NEEDS_VERIFICATION fallback
    """

    async def extract_content(
        self, attachment: GrievanceAttachment, file_path: Optional[Path] = None
    ) -> NormalizedExtractionResult:
        now = datetime.now(timezone.utc)
        engine_name = "voice_stt_adapter_v2"

        audio_bytes = b""
        if file_path and file_path.exists():
            audio_bytes = file_path.read_bytes()

        # Ephemeral storage safeguard: recover audio bytes directly from DB base64 if disk copy missing
        if (not audio_bytes or len(audio_bytes) == 0) and getattr(attachment, "file_content_base64", None):
            try:
                audio_bytes = base64.b64decode(attachment.file_content_base64)
                if file_path:
                    file_path.parent.mkdir(parents=True, exist_ok=True)
                    file_path.write_bytes(audio_bytes)
            except Exception as b64_err:
                logger.warning(f"Failed to decode attachment audio base64: {b64_err}")

        if not audio_bytes:
            return NormalizedExtractionResult(
                source_type=attachment.attachment_type or AttachmentType.VOICE_RECORDING,
                source_attachment_id=attachment.id,
                original_language="ml",
                extracted_text=None,
                extraction_status=ExtractionStatus.FAILED,
                confidence_score=None,
                engine_name=engine_name,
                processed_at=now,
                error_message="Voice audio recording could not be loaded or is empty.",
            )

        mime_type = _normalize_audio_mime(file_path, attachment.mime_type) if file_path else "audio/wav"
        filename = attachment.original_filename or (file_path.name if file_path else "voice_petition.m4a")

        # 1. Try Groq Whisper API (whisper-large-v3-turbo / whisper-large-v3)
        groq_key = get_groq_api_key()
        if groq_key:
            for groq_model in ["whisper-large-v3-turbo", "whisper-large-v3"]:
                try:
                    async with httpx.AsyncClient(timeout=25.0) as client:
                        files = {"file": (filename, audio_bytes, mime_type)}
                        data = {
                            "model": groq_model,
                            "response_format": "json",
                            "temperature": "0.0",
                            "prompt": "Malayalam and English public grievance voice complaint in Kerala (കുടിവെള്ളം, റോഡ്, തോട്, കനാൽ, വൈദ്യുതി, പഞ്ചായത്ത്).",
                        }
                        headers = {"Authorization": f"Bearer {groq_key}"}
                        resp = await client.post(
                            "https://api.groq.com/openai/v1/audio/transcriptions",
                            data=data,
                            files=files,
                            headers=headers,
                        )
                        if resp.status_code == 200:
                            res_json = resp.json()
                            text = (res_json.get("text") or "").strip()
                            if text:
                                return NormalizedExtractionResult(
                                    source_type=attachment.attachment_type or AttachmentType.VOICE_RECORDING,
                                    source_attachment_id=attachment.id,
                                    original_language="ml",
                                    extracted_text=text,
                                    extraction_status=ExtractionStatus.COMPLETED,
                                    confidence_score=0.95,
                                    engine_name=f"groq_{groq_model.replace('-', '_')}",
                                    processed_at=now,
                                )
                        else:
                            logger.warning(f"Groq Whisper ({groq_model}) returned HTTP {resp.status_code}: {resp.text[:200]}")
                except Exception as groq_err:
                    logger.warning(f"Groq Whisper ({groq_model}) failed: {groq_err}")

        # 2. Try Google Gemini Multimodal Audio API
        api_key = get_gemini_api_key()
        if api_key:
            prompt = (
                "You are an expert Speech-to-Text transcription engine for Malayalam and English public grievance audio recordings in Kerala.\n"
                "INSTRUCTIONS:\n"
                "1. Transcribe the spoken grievance accurately in its original script (Malayalam script for Malayalam speech, English for English speech).\n"
                "2. Do NOT add introductory commentary or markdown headers.\n"
                "3. Return ONLY the transcribed grievance text."
            )
            encoded_b64 = base64.b64encode(audio_bytes).decode("utf-8")
            payload = {
                "contents": [
                    {
                        "parts": [
                            {"text": prompt},
                            {
                                "inline_data": {
                                    "mime_type": mime_type,
                                    "data": encoded_b64,
                                }
                            },
                        ]
                    }
                ],
                "generationConfig": {
                    "temperature": 0.1,
                    "maxOutputTokens": 1024,
                },
            }
            headers = {
                "Content-Type": "application/json",
                "x-goog-api-key": api_key.strip(),
            }

            try:
                async with httpx.AsyncClient(timeout=30.0) as client:
                    for model_name in [
                        "gemini-2.5-flash-lite",
                        "gemini-2.5-flash",
                        "gemini-2.0-flash",
                        "gemini-flash-lite-latest",
                        "gemini-3.1-flash-lite",
                        "gemini-3.8-flash",
                    ]:
                        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent"
                        resp = await client.post(url, json=payload, headers=headers)
                        if resp.status_code == 200:
                            data = resp.json()
                            candidates = data.get("candidates", [])
                            if candidates:
                                text_parts = candidates[0].get("content", {}).get("parts", [])
                                raw_transcription = "\n".join(
                                    [p.get("text", "") for p in text_parts if p.get("text")]
                                ).strip()
                                if raw_transcription:
                                    return NormalizedExtractionResult(
                                        source_type=attachment.attachment_type or AttachmentType.VOICE_RECORDING,
                                        source_attachment_id=attachment.id,
                                        original_language="ml",
                                        extracted_text=raw_transcription,
                                        extraction_status=ExtractionStatus.COMPLETED,
                                        confidence_score=0.93,
                                        engine_name=f"gemini_audio_stt_{model_name.replace('-', '_')}",
                                        processed_at=now,
                                    )
                        else:
                            logger.warning(f"Gemini Audio STT ({model_name}) HTTP {resp.status_code}")
            except Exception as gemini_err:
                safe_err = str(gemini_err).replace(api_key, "[REDACTED]")
                logger.warning(f"Gemini Audio STT REST failed: {safe_err}")

            # 2b. Try google-genai SDK fallback for Audio
            try:
                from google import genai
                from google.genai import types

                client = genai.Client(api_key=api_key.strip())
                for model_name in ["gemini-2.5-flash-lite", "gemini-2.5-flash", "gemini-2.0-flash", "gemini-flash-lite-latest"]:
                    try:
                        response = await asyncio.to_thread(
                            client.models.generate_content,
                            model=model_name,
                            contents=[
                                types.Part.from_bytes(data=audio_bytes, mime_type=mime_type),
                                prompt,
                            ],
                        )
                        if response and getattr(response, "text", None) and response.text.strip():
                            return NormalizedExtractionResult(
                                source_type=attachment.attachment_type or AttachmentType.VOICE_RECORDING,
                                source_attachment_id=attachment.id,
                                original_language="ml",
                                extracted_text=response.text.strip(),
                                extraction_status=ExtractionStatus.COMPLETED,
                                confidence_score=0.93,
                                engine_name=f"gemini_sdk_audio_{model_name.replace('-', '_')}",
                                processed_at=now,
                            )
                    except Exception as sdk_inner_err:
                        safe_inner = str(sdk_inner_err).replace(api_key, "[REDACTED]")
                        logger.warning(f"Gemini Audio SDK ({model_name}) failed: {safe_inner}")
            except Exception as sdk_err:
                pass

        # 3. Try OpenAI Whisper API (whisper-1) if OPENAI_API_KEY is available
        openai_key = get_openai_api_key()
        if openai_key:
            try:
                async with httpx.AsyncClient(timeout=15.0) as client:
                    files = {"file": (filename, audio_bytes, mime_type)}
                    data = {"model": "whisper-1"}
                    headers = {"Authorization": f"Bearer {openai_key}"}
                    resp = await client.post(
                        "https://api.openai.com/v1/audio/transcriptions",
                        data=data,
                        files=files,
                        headers=headers,
                    )
                    if resp.status_code == 200:
                        text = (resp.json().get("text") or "").strip()
                        if text:
                            return NormalizedExtractionResult(
                                source_type=attachment.attachment_type or AttachmentType.VOICE_RECORDING,
                                source_attachment_id=attachment.id,
                                original_language="ml",
                                extracted_text=text,
                                extraction_status=ExtractionStatus.COMPLETED,
                                confidence_score=0.94,
                                engine_name="openai_whisper_1",
                                processed_at=now,
                            )
            except Exception as oai_err:
                logger.warning(f"OpenAI Whisper STT failed: {oai_err}")

        # 4. Try Local Whisper Model if installed (non-Render only)
        whisper_model = get_local_whisper()
        if whisper_model != "unavailable" and whisper_model is not None:
            try:
                res = await asyncio.wait_for(
                    asyncio.to_thread(whisper_model.transcribe, str(file_path), language="ml"),
                    timeout=12.0,
                )
                transcribed_text = res.get("text", "").strip()
                if transcribed_text:
                    return NormalizedExtractionResult(
                        source_type=attachment.attachment_type or AttachmentType.VOICE_RECORDING,
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

        # 5. Graceful Fallback if audio STT unavailable
        return NormalizedExtractionResult(
            source_type=attachment.attachment_type or AttachmentType.VOICE_RECORDING,
            source_attachment_id=attachment.id,
            original_language="ml",
            extracted_text=None,
            extraction_status=ExtractionStatus.NEEDS_VERIFICATION,
            confidence_score=None,
            engine_name="voice_stt_fallback",
            processed_at=now,
            error_message="Automatic voice transcription requires verification. Your voice recording is safely attached — please review or enter a brief description below.",
        )
