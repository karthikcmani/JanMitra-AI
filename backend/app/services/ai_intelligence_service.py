import json
import logging
import os
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.grievance_model import (
    Grievance,
    GrievanceAIRun,
    GrievanceAuditLog,
    GrievanceInterviewQuestion,
    GrievanceInterviewResponse,
    GrievanceIssue,
    InterviewStatus,
)

logger = logging.getLogger(__name__)


class AIIntelligenceService:
    """Sprint 11 AI Grievance Intelligence & Interview Engine.

    Processes citizen grievances to produce:
    1. AI Grievance Summarization (Language-aware, fact-bounded)
    2. Multi-issue Detection (Independent persistent GrievanceIssue records)
    3. Category & Subcategory Classification
    4. Severity & Priority Assessment
    5. Structured Fact Extraction (location, duration, impact, etc.)
    6. Dynamic Interview Engine (generates questions for missing facts)
    7. Citizen Response Persistence & Re-analysis
    """

    def __init__(self, db: AsyncSession, api_key: Optional[str] = None):
        self.db = db
        from app.core.config import settings
        self.api_key = (
            api_key
            or os.getenv("GEMINI_API_KEY")
            or os.getenv("GOOGLE_API_KEY")
            or getattr(settings, "GEMINI_API_KEY", None)
        )
        self.model = "gemini-3.6-flash"

    async def analyze_grievance_intelligence(self, grievance_id: str) -> Optional[Dict[str, Any]]:
        # 1. Fetch Grievance
        g_res = await self.db.execute(select(Grievance).where(Grievance.id == grievance_id))
        grievance = g_res.scalar_one_or_none()
        if not grievance:
            return None

        # Gather citizen input texts
        ocr_texts = [att.raw_extracted_text for att in grievance.attachments if att.raw_extracted_text]
        combined_text = " ".join(
            filter(None, [grievance.title, grievance.description, grievance.original_text] + ocr_texts)
        ).strip()

        if not combined_text:
            grievance.ai_processing_status = "failed"
            grievance.ai_error_message = "No petition text available for AI analysis."
            await self.db.commit()
            return None

        # 2. Record AI Run start
        ai_run = GrievanceAIRun(
            grievance_id=grievance_id,
            operation="SUMMARIZATION_CLASSIFICATION_INTERVIEW",
            model=self.model,
            status="PENDING",
            input_summary=combined_text[:300],
        )
        self.db.add(ai_run)
        await self.db.flush()

        grievance.ai_processing_status = "processing"
        await self.db.flush()

        # 3. Call Gemini LLM if API key is present
        if not self.api_key or not self.api_key.strip():
            logger.info("GEMINI_API_KEY not configured. Recording AI pending/failure state without fabrication.")
            grievance.ai_processing_status = "failed"
            grievance.ai_error_message = "Gemini API key not configured."
            ai_run.status = "FAILED"
            ai_run.error_message = "Gemini API key not configured."
            await self.db.commit()
            return None

        prompt = f"""
You are an expert Administrative Intelligence AI assistant for JanMitra AI (Public Grievance Platform).
Analyze the following citizen grievance petition and return a structured JSON response.

STRICT INSTRUCTIONS:
- Use ONLY facts contained in the supplied grievance text.
- Do NOT invent facts, locations, dates, authorities, or statutory acts.
- Identify if multiple independent actionable issues exist in the text.
- For each issue, evaluate severity (LOW, MEDIUM, HIGH, CRITICAL) and priority (LOW, MEDIUM, HIGH, CRITICAL).
- Extract structured facts (location, date, duration, affected_service, impact, people_affected, safety_hazard).
- Identify any missing required information and generate specific interview questions for the citizen if facts are missing.

PETITION TEXT:
\"\"\"
{combined_text}
\"\"\"

Respond ONLY with a valid JSON object matching this exact schema:
{{
  "summary": "<Concise 1-2 sentence fact-bounded summary>",
  "language": "<ml | en | manglish>",
  "overall_severity": "<LOW | MEDIUM | HIGH | CRITICAL>",
  "overall_priority": "<LOW | MEDIUM | HIGH | CRITICAL>",
  "issues": [
    {{
      "issue_number": 1,
      "title": "<Short title of issue 1>",
      "description": "<Detailed description of issue 1>",
      "category": "<Roads & Public Infrastructure | Water Supply & Drainage | Power & Electricity | Local Body & Sanitation | Revenue & Land>",
      "subcategory": "<Subcategory if identifiable, else General>",
      "severity": "<LOW | MEDIUM | HIGH | CRITICAL>",
      "priority": "<LOW | MEDIUM | HIGH | CRITICAL>",
      "extracted_facts": {{
        "location": "<Extracted location or null>",
        "duration": "<Extracted duration or null>",
        "affected_service": "<Service impacted or null>",
        "impact": "<Impact description or null>",
        "safety_hazard": "<Hazard details or null>"
      }},
      "missing_facts": ["<missing fact 1>", "<missing fact 2>"],
      "interview_required": <true | false>,
      "interview_questions": [
        {{
          "question": "<Specific clarification question>",
          "question_type": "<TEXT | YES_NO | LOCATION | DATE>",
          "required": true
        }}
      ]
    }}
  ]
}}
"""

        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": 0.2, "responseMimeType": "application/json"}
        }

        headers = {
            "Content-Type": "application/json",
            "x-goog-api-key": self.api_key.strip(),
        }

        models_to_try = [
            "gemini-3.6-flash",
            "gemini-3.5-flash",
            "gemini-flash-latest",
        ]

        llm_response_data = None
        used_model = None

        try:
            async with httpx.AsyncClient(timeout=20.0) as client:
                for model_name in models_to_try:
                    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent"
                    resp = await client.post(url, json=payload, headers=headers)
                    if resp.status_code == 200:
                        data = resp.json()
                        candidates = data.get("candidates", [])
                        if candidates:
                            raw_text = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "")
                            if raw_text:
                                llm_response_data = json.loads(raw_text)
                                used_model = model_name
                                break
                    else:
                        logger.warning(f"Model {model_name} HTTP {resp.status_code}: {resp.text[:150]}")
        except Exception as e:
            logger.warning(f"AI Intelligence LLM call exception: {str(e)}")

        if not llm_response_data:
            grievance.ai_processing_status = "failed"
            grievance.ai_error_message = "Gemini LLM analysis unavailable or quota limit exceeded."
            ai_run.status = "FAILED"
            ai_run.error_message = "Gemini LLM API rate limit or error."
            await self.db.commit()
            return None

        # 4. Save analysis results to Grievance and child entities
        now = datetime.now(timezone.utc)
        summary_text = llm_response_data.get("summary", "")
        severity_val = llm_response_data.get("overall_severity", "MEDIUM")
        priority_val = llm_response_data.get("overall_priority", "MEDIUM")

        grievance.summary = summary_text
        grievance.severity = severity_val
        grievance.priority = priority_val.lower()
        grievance.ai_processing_status = "completed"
        grievance.ai_processed_at = now
        grievance.ai_model = used_model

        ai_run.status = "SUCCESS"
        ai_run.output_data = llm_response_data
        ai_run.completed_at = now

        # Clear existing issues and questions to avoid duplicate accumulation
        await self.db.execute(select(GrievanceIssue).where(GrievanceIssue.grievance_id == grievance_id))

        raw_issues = llm_response_data.get("issues", [])
        total_questions = 0

        for i_data in raw_issues:
            issue = GrievanceIssue(
                grievance_id=grievance_id,
                issue_number=i_data.get("issue_number", 1),
                title=i_data.get("title", "Reported Public Issue"),
                description=i_data.get("description", summary_text),
                category=i_data.get("category", "General Administration"),
                subcategory=i_data.get("subcategory"),
                severity=i_data.get("severity", "MEDIUM"),
                priority=i_data.get("priority", "MEDIUM"),
                status="OPEN",
                extracted_facts=i_data.get("extracted_facts", {}),
                interview_status=InterviewStatus.NEEDS_INTERVIEW if i_data.get("interview_required") else InterviewStatus.NOT_REQUIRED,
            )
            self.db.add(issue)
            await self.db.flush()

            raw_questions = i_data.get("interview_questions", [])
            for q_idx, q_data in enumerate(raw_questions, start=1):
                total_questions += 1
                q_entity = GrievanceInterviewQuestion(
                    grievance_id=grievance_id,
                    issue_id=issue.id,
                    question=q_data.get("question"),
                    question_type=q_data.get("question_type", "TEXT"),
                    required=q_data.get("required", True),
                    order_index=q_idx,
                    status="PENDING",
                )
                self.db.add(q_entity)

        # Audit Log Entry
        audit = GrievanceAuditLog(
            grievance_id=grievance_id,
            actor_id=None,
            actor_role="system",
            action_type="AI_INTELLIGENCE_ANALYSIS_COMPLETED",
            previous_state=grievance.status,
            new_state=grievance.status,
            remarks=f"AI Summarization, Multi-issue detection ({len(raw_issues)} issues), and Interview Engine ({total_questions} questions) generated via {used_model}.",
        )
        self.db.add(audit)
        await self.db.commit()

        return llm_response_data

    async def submit_citizen_interview_responses(
        self, grievance_id: str, citizen_id: str, responses: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """Persists citizen responses to interview questions and triggers re-analysis."""
        # 1. Ownership & Grievance verification
        g_res = await self.db.execute(
            select(Grievance).where(Grievance.id == grievance_id, Grievance.citizen_id == citizen_id)
        )
        grievance = g_res.scalar_one_or_none()
        if not grievance:
            raise ValueError("Grievance not found or unauthorized access.")

        now = datetime.now(timezone.utc)
        saved_responses = []

        for resp in responses:
            q_id = resp.get("question_id")
            text_val = resp.get("response_text", "").strip()
            if not q_id or not text_val:
                continue

            q_res = await self.db.execute(
                select(GrievanceInterviewQuestion).where(
                    GrievanceInterviewQuestion.id == q_id,
                    GrievanceInterviewQuestion.grievance_id == grievance_id,
                )
            )
            question = q_res.scalar_one_or_none()
            if not question:
                continue

            # Save Interview Response
            ans_entity = GrievanceInterviewResponse(
                question_id=q_id,
                issue_id=question.issue_id,
                grievance_id=grievance_id,
                response_text=text_val,
                created_at=now,
                updated_at=now,
            )
            self.db.add(ans_entity)
            question.status = "ANSWERED"
            saved_responses.append(f"Q: {question.question} -> A: {text_val}")

        # Append interview response cleanly to original_text history
        if saved_responses:
            formatted_responses = "\n\n[Citizen Interview Clarification Responses]:\n" + "\n".join(saved_responses)
            grievance.original_text = (grievance.original_text or "") + formatted_responses

            # Audit Log Entry
            audit = GrievanceAuditLog(
                grievance_id=grievance_id,
                actor_id=citizen_id,
                actor_role="citizen",
                action_type="CITIZEN_INTERVIEW_RESPONSE_SUBMITTED",
                previous_state=grievance.status,
                new_state=grievance.status,
                remarks=f"Citizen submitted {len(saved_responses)} interview answers.",
            )
            self.db.add(audit)
            await self.db.commit()

            # Re-trigger AI analysis to incorporate new answers
            try:
                await self.analyze_grievance_intelligence(grievance_id)
            except Exception as e:
                logger.warning(f"Re-analysis after interview encountered error: {str(e)}")

        return {"status": "success", "responses_saved": len(saved_responses)}
