import json
import logging
import os
from typing import Any, Dict, Optional
import httpx

logger = logging.getLogger(__name__)


class GeminiAnalysisResult:
    def __init__(
        self,
        category: str,
        department_name: str,
        summary: str,
        key_entities: list[str],
        priority: str,
        statutory_reference: str,
        reasoning: str,
        confidence_score: float,
    ):
        self.category = category
        self.department_name = department_name
        self.summary = summary
        self.key_entities = key_entities
        self.priority = priority
        self.statutory_reference = statutory_reference
        self.reasoning = reasoning
        self.confidence_score = confidence_score


class GeminiGrievanceAnalyzer:
    """Gemini AI Grievance Intelligence Service with Safe Fallback.

    Analyzes intake grievance petitions, performs Malayalam/English NLP extraction,
    categorizes departmental jurisdiction, and recommends statutory grounding.
    """

    def __init__(self, api_key: Optional[str] = None):
        from app.core.config import settings
        self.api_key = (
            api_key
            or os.getenv("GEMINI_API_KEY")
            or os.getenv("GOOGLE_API_KEY")
            or getattr(settings, "GEMINI_API_KEY", None)
        )
        self.model = "gemini-3.6-flash"
        self.endpoint = f"https://generativelanguage.googleapis.com/v1beta/models/{self.model}:generateContent"

    async def analyze_grievance(self, grievance_text: str) -> Optional[GeminiAnalysisResult]:
        if not self.api_key or not self.api_key.strip():
            logger.info("GEMINI_API_KEY environment variable is not configured. Skipping Gemini LLM analysis.")
            return None

        if not grievance_text or not grievance_text.strip():
            return None

        prompt = f"""
You are an expert Administrative Intelligence AI assistant for JanMitra AI (Public Grievance Platform).
Analyze the following citizen grievance petition (which may be written in Malayalam, English, or Manglish) and extract structured decision support information.

STRICT KERALA GOVERNMENT JURISDICTION RULES:
1. REVENUE & GENERAL ADMINISTRATION:
   - If the petition is addressed to Tahsildar (തഹസിൽദാർ), Taluk Office (താലൂക്ക് ഓഫീസ്), Village Office (വില്ലേജ് ഓഫീസ്), or District Collector.
   - If it involves government poramboke land (സർക്കാർ പുറമ്പോക്ക്), canal/stream encroachment (തോട് / കനാൽ കയ്യേറ്റം), resurvey (റീ-സർവേ), land demarcation (അളന്നു തിട്ടപ്പെടുത്തൽ), paddy/wetland filling (നെൽവയൽ നികത്തൽ), or pattayam.
   - Statutory Act: "Kerala Land Conservancy Act, 1957 (Sections 3, 7 & 11)"
   - Department: "Revenue & General Administration"
   - Category: "Revenue & General Administration"
   - NOTE: Poramboke canal encroachment or natural water flow obstruction is STRICTLY Revenue jurisdiction, NEVER Kerala Water Authority!

2. KERALA WATER AUTHORITY (KWA):
   - ONLY for piped drinking water supply (കുടിവെള്ള വിതരണം), water pipeline bursts or leaks (പൈപ്പ് പൊട്ടൽ / ചോർച്ച), water connections, or faulty water meters.
   - Statutory Act: "Kerala Water Supply and Sewerage Act, 1986 (Section 14)"
   - Department: "Kerala Water Authority (KWA)"
   - Category: "Water Supply & Drainage"

3. PUBLIC WORKS DEPARTMENT (PWD):
   - For public roads, potholes (റോഡിലെ കുഴികൾ), bridges (പാലം), culverts (കലുങ്ക്), road tarring, and state highways.
   - Statutory Act: "Kerala Highway Protection Act, 1999 (Section 7)"
   - Department: "Public Works Department (PWD)"
   - Category: "Roads & Public Infrastructure"

4. KERALA STATE ELECTRICITY BOARD (KSEB):
   - For electricity interruptions, electric poles (പോസ്റ്റ്), power lines (കമ്പി), transformers, or voltage issues.
   - Statutory Act: "Electricity Act, 2003 (Section 43) & Kerala Electricity Supply Code, 2014"
   - Department: "Kerala State Electricity Board (KSEB)"
   - Category: "Power & Electricity"

5. LOCAL SELF GOVERNMENT DEPARTMENT (LSGD / Panchayat / Municipality):
   - For ward garbage/waste dumping (മാലിന്യം), street drainage gutters (ഓട), streetlights (തെരുവ് വിളക്ക്), public sanitation, or building permits.
   - Statutory Act: "Kerala Panchayat Raj Act, 1994 (Section 166 & 218)"
   - Department: "Local Self Government Department (LSGD / Panchayat)"
   - Category: "Local Body & Public Health"

PETITION TEXT:
\"\"\"
{grievance_text}
\"\"\"

Respond ONLY with a valid JSON object matching this exact schema:
{{
  "category": "<One of: Water Supply & Drainage | Roads & Public Infrastructure | Power & Electricity | Local Body & Public Health | Revenue & General Administration>",
  "department_name": "<One of: Kerala Water Authority (KWA) | Public Works Department (PWD) | Kerala State Electricity Board (KSEB) | Local Self Government Department (LSGD / Panchayat) | Revenue & General Administration>",
  "summary": "<Concise 1-2 sentence English summary of the issue>",
  "key_entities": ["<entity1>", "<entity2>"],
  "priority": "<high | medium | low>",
  "statutory_reference": "<Relevant Indian / Kerala Statutory Act & Section>",
  "reasoning": "<1-2 sentence administrative justification for department assignment>",
  "confidence_score": <float between 0.80 and 0.99>
}}
"""

        payload = {
            "contents": [
                {
                    "parts": [
                        {"text": prompt}
                    ]
                }
            ],
            "generationConfig": {
                "temperature": 0.2,
                "responseMimeType": "application/json",
            }
        }

        headers = {
            "Content-Type": "application/json",
            "x-goog-api-key": self.api_key.strip(),
        }

        models_to_try = [
            "gemini-3.1-flash-lite",
            "gemini-3.8-flash",
            "gemini-3.7-flash",
            "gemini-flash-lite-latest",
        ]

        try:
            async with httpx.AsyncClient(timeout=12.0) as client:
                for model_name in models_to_try:
                    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent"
                    resp = await client.post(url, json=payload, headers=headers)
                    if resp.status_code == 200:
                        data = resp.json()
                        candidates = data.get("candidates", [])
                        if not candidates:
                            continue

                        raw_json_str = (
                            candidates[0]
                            .get("content", {})
                            .get("parts", [{}])[0]
                            .get("text", "")
                        )
                        if not raw_json_str:
                            continue

                        parsed = json.loads(raw_json_str)

                        return GeminiAnalysisResult(
                            category=parsed.get("category", "Revenue & General Administration"),
                            department_name=parsed.get(
                                "department_name", "Revenue & General Administration"
                            ),
                            summary=parsed.get("summary", grievance_text[:200]),
                            key_entities=parsed.get("key_entities", []),
                            priority=parsed.get("priority", "medium"),
                            statutory_reference=parsed.get(
                                "statutory_reference", "Kerala Public Services Act, 2012"
                            ),
                            reasoning=parsed.get(
                                "reasoning",
                                "Assigned based on natural language petition analysis.",
                            ),
                            confidence_score=float(parsed.get("confidence_score", 0.92)),
                        )
                    elif resp.status_code == 429:
                        logger.warning(
                            f"Gemini API model {model_name} quota exhausted (429). Fast-failing to sequential engine fallback."
                        )
                        break
                    else:
                        logger.warning(
                            f"Gemini API model {model_name} returned non-200 status code {resp.status_code}: {resp.text[:200]}"
                        )
        except Exception as e:
            logger.warning(
                f"Gemini LLM analysis encountered non-fatal error: {str(e)}. Using sequential engine fallback."
            )

        # Resilient fallback using SequentialRoutingEngine
        from app.services.sequential_routing_engine import SequentialRoutingEngine
        decision = SequentialRoutingEngine.evaluate(grievance_text)
        return GeminiAnalysisResult(
            category=decision.category,
            department_name=decision.department_name,
            summary=f"Grievance regarding {decision.category}: {grievance_text[:200]}...",
            key_entities=[decision.detected_subject or decision.department_name],
            priority="high" if any(k in grievance_text.lower() for k in ["അടിയന്തര", "urgent", "hazard", "danger"]) else "medium",
            statutory_reference=decision.statutory_act,
            reasoning=decision.legal_explanation,
            confidence_score=decision.confidence_score,
        )
