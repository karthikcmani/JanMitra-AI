import re
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from fastapi import HTTPException, status
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.grievance_model import (
    ExtractionStatus,
    Grievance,
    GrievanceAnalysis,
    GrievanceAttachment,
    GrievanceAuditLog,
    GrievanceStatus,
)
from app.models.user_model import User
from app.repositories.grievance_repository import GrievanceRepository
from app.services.extraction_service import FastAutoExtractionAdapter


class DepartmentRoutingInfo(BaseModel):
    department_code: str
    department_name: str
    category: str
    confidence_score: float
    matched_keywords: List[str]
    statutory_reference: str
    legal_explanation: str


class AIDecisionSupportPanel(BaseModel):
    suggested_department: str
    priority: str
    priority_score: Optional[int] = 50
    priority_breakdown: Optional[Dict[str, Any]] = None
    sla_target_days: Optional[int] = 7
    reasoning: str
    key_facts: List[str] = []
    statutory_relevance: str
    missing_information: str
    suggested_next_step: str
    confidence_score: float
    disclaimer: str = "AI-assisted recommendation. Administrative official retains final decision-making responsibility."


class OfficialGrievanceDetailResponse(BaseModel):
    id: str
    grievance_number: str
    citizen_id: str
    citizen_name: Optional[str] = None
    citizen_phone: Optional[str] = None
    petitioner_name: Optional[str] = None
    filing_type: Optional[str] = "self"
    relationship: Optional[str] = None
    petitioner_phone: Optional[str] = None
    title: Optional[str] = None
    description: Optional[str] = None
    intake_mode: str
    original_language: str
    original_text: Optional[str] = None
    raw_ocr_text: Optional[str] = None
    status: str
    priority: str
    priority_score: Optional[int] = 50
    priority_breakdown: Optional[Dict[str, Any]] = None
    sla_target_days: Optional[int] = 7
    predicted_department: Optional[str] = None
    assigned_department: Optional[str] = None
    assigned_official_id: Optional[str] = None
    assigned_official_name: Optional[str] = None
    category: Optional[str] = None
    official_clarification_question: Optional[str] = None
    legal_grounding_references: Optional[Dict[str, Any]] = None
    ai_explanation: Optional[str] = None
    decision_support: Optional[AIDecisionSupportPanel] = None
    attachments: List[Dict[str, Any]] = []
    audit_logs: List[Dict[str, Any]] = []
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class OfficialDashboardSummaryResponse(BaseModel):
    total_grievances: int
    pending: int
    under_processing: int
    clarification_required: int
    forwarded: int
    resolved: int
    high_priority: int
    today_received: int
    recent_grievances: List[OfficialGrievanceDetailResponse] = []


class DepartmentWorkloadResponse(BaseModel):
    department_name: str
    pending: int
    under_processing: int
    clarification_required: int
    forwarded: int
    resolved: int
    total: int



class OfficialActionRequest(BaseModel):
    department_name: Optional[str] = Field(None, max_length=150)
    assigned_official_id: Optional[str] = Field(None, max_length=36)
    remarks: Optional[str] = None
    new_status: Optional[str] = Field(None, max_length=50)
    question: Optional[str] = None


class OfficialService:
    DEPARTMENT_RULES = [
        {
            "code": "REV",
            "name": "Revenue & General Administration",
            "category": "Revenue & Land Reforms",
            "keywords": [
                "തഹസിൽദാർ", "താലൂക്ക്", "വില്ലേജ്", "പുറമ്പോക്ക്", "സർക്കാർ പുറമ്പോക്ക്",
                "കയ്യേറ്റം", "കയ്യേറ്റം ഒഴിപ്പിച്ച്", "കയ്യേറി", "തോട്", "തോടിലെ", "തോട്ടിലെ",
                "സ്വാഭാവിക നീരൊഴുക്ക്", "അളന്നു തിട്ടപ്പെടുത്തി", "അളന്നു", "റീ-സർവേ",
                "സർവേ നമ്പർ", "റീ സർവെ", "പട്ടയം", "ഭൂമി", "നിലം നികത്തൽ", "തണ്ണീർത്തടം",
                "മണ്ണ് നികത്തൽ", "വേലി കെട്ടി", "റവന്യൂ ഉദ്യോഗസ്ഥർ", "റവന്യൂ വകുപ്പ്",
                "poramboke", "puramboke", "encroachment", "resurvey", "tahsildar", "taluk", "survey"
            ],
            "statutory_reference": "Kerala Land Conservancy Act, 1957 (Sections 3, 7 & 11)",
            "legal_explanation": "Complaint pertains to government poramboke land, canal encroachment, or survey demarcation under Tahsildar / Revenue jurisdiction.",
        },
        {
            "code": "PWD",
            "name": "Public Works Department (PWD)",
            "category": "Roads & Public Infrastructure",
            "keywords": [
                "പൊതുമരാമത്ത്", "റോഡ്", "റോഡിലെ", "കുഴി", "കുഴികൾ", "പണി", "കലുങ്ക്", "പാലം",
                "ടാർ", "ടാറിങ്", "ഗതാഗതം", "വാഹനങ്ങൾ", "റോഡുകൾ", "ഹൈവേ", "road", "pothole",
                "potholes", "bridge", "pwd", "highway", "tarring", "culvert"
            ],
            "statutory_reference": "Kerala Highway Protection Act, 1999 (Section 7)",
            "legal_explanation": "Complaint involves road maintenance, pothole repair, or culvert construction under PWD oversight.",
        },
        {
            "code": "KWA",
            "name": "Kerala Water Authority (KWA)",
            "category": "Water Supply & Drainage",
            "keywords": [
                "കുടിവെള്ളം", "കുടിവെള്ള വിതരണം", "പൈപ്പ്", "പൈപ്പ് ലൈൻ", "പൈപ്പ് പൊട്ടി",
                "കുടിവെള്ള പൈപ്പ്", "ചോർച്ച", "വാട്ടർ മീറ്റർ", "ടാപ്പ്", "വാട്ടർ കണക്ഷൻ",
                "ജല അതോറിറ്റി", "വാട്ടർ അതോറിറ്റി", "drinking water", "pipe burst", "pipe leak", "kwa"
            ],
            "statutory_reference": "Kerala Water Supply and Sewerage Act, 1986 (Section 14)",
            "legal_explanation": "Complaint relates to public drinking water supply interruption or pipe damage under KWA jurisdiction.",
        },
        {
            "code": "KSEB",
            "name": "Kerala State Electricity Board (KSEB)",
            "category": "Power & Electricity",
            "keywords": [
                "വൈദ്യുതി", "ഇലക്ട്രിക്", "ട്രാൻസ്ഫോർമർ", "പോസ്റ്റ്", "സ്ട്രീറ്റ് ലൈറ്റ്", "വോൾട്ടേജ്",
                "വൈദ്യുത", "ലൈൻ", "കെ.എസ്.ഇ.ബി", "കെഎസ്ഇബി", "power", "electricity", "kseb", "light",
                "transformer", "voltage"
            ],
            "statutory_reference": "Electricity Act, 2003 (Section 43)",
            "legal_explanation": "Complaint pertains to power outages, damaged electricity poles, or transformer faults managed by KSEB.",
        },
        {
            "code": "LSGD",
            "name": "Local Self Government Department (LSGD / Panchayat)",
            "category": "Local Body & Public Health",
            "keywords": [
                "മാലിന്യം", "പഞ്ചായത്ത്", "മുനിസിപ്പാലിറ്റി", "വീട്ടുനികുതി", "ശുചിത്വം", "തെരുവ്",
                "ഗ്രാമപഞ്ചായത്ത്", "waste", "sanitation", "panchayat", "municipality", "cleanliness"
            ],
            "statutory_reference": "Kerala Panchayat Raj Act, 1994 (Section 166)",
            "legal_explanation": "Complaint involves local ward sanitation, municipal waste management, or Grama Panchayat civic services.",
        },
    ]

    def __init__(self, db: AsyncSession):
        self.db = db
        self.repo = GrievanceRepository(db)

    def analyze_department_routing(self, text: str) -> DepartmentRoutingInfo:
        from app.services.sequential_routing_engine import SequentialRoutingEngine
        decision = SequentialRoutingEngine.evaluate(text)
        return DepartmentRoutingInfo(
            department_code=decision.department_code,
            department_name=decision.department_name,
            category=decision.category,
            confidence_score=decision.confidence_score,
            matched_keywords=decision.sequential_trace,
            statutory_reference=decision.statutory_act,
            legal_explanation=decision.legal_explanation,
        )

    async def get_official_grievance_by_id(self, grievance_id: str) -> Optional[OfficialGrievanceDetailResponse]:
        from sqlalchemy.orm import selectinload
        res = await self.db.execute(
            select(Grievance)
            .options(
                selectinload(Grievance.attachments),
                selectinload(Grievance.audit_logs),
                selectinload(Grievance.citizen),
                selectinload(Grievance.assigned_official),
                selectinload(Grievance.analysis),
            )
            .where(Grievance.id == grievance_id)
        )
        g = res.scalar_one_or_none()
        if not g:
            return None
        return await self._build_official_detail_response(g)

    async def get_all_official_grievances(self) -> List[OfficialGrievanceDetailResponse]:
        from sqlalchemy.orm import selectinload
        stmt = (
            select(Grievance)
            .options(
                selectinload(Grievance.attachments),
                selectinload(Grievance.audit_logs),
                selectinload(Grievance.citizen),
                selectinload(Grievance.assigned_official),
                selectinload(Grievance.analysis),
            )
            .order_by(Grievance.created_at.desc())
        )
        res = await self.db.execute(stmt)
        grievances = res.scalars().all()
        return [await self._build_official_detail_response(g) for g in grievances]

    async def _build_official_detail_response(self, g: Grievance) -> OfficialGrievanceDetailResponse:
        # Fetch citizen user details safely without triggering lazy-load MissingGreenlet
        citizen = g.__dict__.get("citizen")
        if not citizen and g.citizen_id:
            citizen_res = await self.db.execute(select(User).where(User.id == g.citizen_id))
            citizen = citizen_res.scalar_one_or_none()

        assigned_off_name = None
        assigned_off = g.__dict__.get("assigned_official")
        if assigned_off:
            assigned_off_name = assigned_off.full_name
        elif getattr(g, "assigned_official_id", None):
            off_res = await self.db.execute(select(User).where(User.id == g.assigned_official_id))
            off_user = off_res.scalar_one_or_none()
            if off_user:
                assigned_off_name = off_user.full_name

        # Fetch attachments safely without triggering lazy-load MissingGreenlet
        attachments = g.__dict__.get("attachments")
        if attachments is None:
            atts_res = await self.db.execute(
                select(GrievanceAttachment).where(GrievanceAttachment.grievance_id == g.id)
            )
            attachments = atts_res.scalars().all()

        # Aggregate raw OCR text
        raw_ocr = "\n".join(
            [a.raw_extracted_text for a in attachments if a.raw_extracted_text]
        )

        # Fetch analysis safely without triggering lazy-load MissingGreenlet
        analysis = g.__dict__.get("analysis")
        if analysis is None:
            analysis_res = await self.db.execute(
                select(GrievanceAnalysis).where(GrievanceAnalysis.grievance_id == g.id)
            )
            analysis = analysis_res.scalar_one_or_none()

        # Fetch audit logs safely without triggering lazy-load MissingGreenlet
        audit_logs = g.__dict__.get("audit_logs")
        if audit_logs is None:
            logs_res = await self.db.execute(
                select(GrievanceAuditLog)
                .where(GrievanceAuditLog.grievance_id == g.id)
                .order_by(GrievanceAuditLog.created_at.asc())
            )
            audit_logs = logs_res.scalars().all()

        from app.services.sequential_routing_engine import SequentialRoutingEngine
        eval_text = (g.title or "") + " " + (g.description or "") + " " + (raw_ocr or g.original_text or "")
        seq_dec = SequentialRoutingEngine.evaluate(eval_text)

        dept_suggestion = g.department_id or (analysis.predicted_category if (analysis and analysis.predicted_category) else seq_dec.department_name)
        if not dept_suggestion or not str(dept_suggestion).strip():
            dept_suggestion = seq_dec.department_name

        statutory_info = None
        if analysis and analysis.legal_grounding_references:
            statutory_info = analysis.legal_grounding_references.get("statutory_act")
        if not statutory_info or statutory_info == "Kerala Public Services Act, 2012":
            statutory_info = seq_dec.statutory_act

        explanation_text = analysis.ai_explanation if (analysis and analysis.ai_explanation) else seq_dec.legal_explanation
        if not explanation_text or explanation_text == "Assigned based on natural language petition context.":
            explanation_text = seq_dec.legal_explanation

        confidence_val = float(analysis.legal_grounding_references.get("confidence_score", seq_dec.confidence_score)) if (analysis and analysis.legal_grounding_references) else seq_dec.confidence_score

        missing_info = "None identified."
        if g.status == GrievanceStatus.CLARIFICATION_REQUIRED:
            missing_info = "Official requested additional evidence/land details from citizen."
        elif not raw_ocr and g.intake_mode == "ocr_handwritten":
            missing_info = "Petition scan attached but OCR text not yet extracted."

        next_step = "Review petition evidence and assign to Executive Engineer."
        if g.status == GrievanceStatus.CLARIFICATION_REQUIRED:
            next_step = "Awaiting citizen clarification response."
        elif g.status == GrievanceStatus.FORWARDED:
            next_step = "Track departmental resolution progress with assigned officer."

        from app.services.priority_engine import PriorityIntelligenceEngine
        p_score = getattr(g, "priority_score", None)
        p_breakdown = None
        sla_days = 7

        if analysis and analysis.extracted_entities and isinstance(analysis.extracted_entities, dict):
            p_eval = analysis.extracted_entities.get("priority_evaluation")
            if p_eval:
                p_score = p_eval.get("priority_score", p_score or 50)
                p_breakdown = p_eval.get("factors")
                sla_days = p_eval.get("sla_target_days", 7)

        if p_score is None:
            eval_text = (g.title or "") + " " + (g.description or "") + " " + (raw_ocr or g.original_text or "")
            p_res = PriorityIntelligenceEngine.evaluate(eval_text, department=dept_suggestion)
            p_score = p_res.priority_score
            p_breakdown = p_res.factors
            sla_days = p_res.sla_target_days

        decision_panel = AIDecisionSupportPanel(
            suggested_department=dept_suggestion,
            priority=g.priority,
            priority_score=p_score,
            priority_breakdown=p_breakdown,
            sla_target_days=sla_days,
            reasoning=explanation_text,
            key_facts=[
                f"Category: {g.category or 'General'}",
                f"Language: {g.original_language}",
                f"Priority Score: {p_score}/100 (SLA: {sla_days} days)",
            ],
            statutory_relevance=statutory_info,
            missing_information=missing_info,
            suggested_next_step=next_step,
            confidence_score=confidence_val,
        )

        return OfficialGrievanceDetailResponse(
            id=g.id,
            grievance_number=g.grievance_number,
            citizen_id=g.citizen_id,
            citizen_name=citizen.full_name if citizen else "Citizen User",
            citizen_phone=citizen.phone if citizen else None,
            petitioner_name=getattr(g, "petitioner_name", None) or (citizen.full_name if citizen else "Citizen User"),
            filing_type=getattr(g, "filing_type", "self") or "self",
            relationship=getattr(g, "petitioner_relationship", None) or getattr(g, "relationship", None),
            petitioner_phone=getattr(g, "petitioner_phone", None) or (citizen.phone if citizen else None),
            title=g.title,
            description=g.description,
            intake_mode=g.intake_mode,
            original_language=g.original_language,
            original_text=g.original_text,
            raw_ocr_text=raw_ocr if raw_ocr else g.original_text,
            status=g.status,
            priority=g.priority,
            priority_score=p_score,
            priority_breakdown=p_breakdown,
            sla_target_days=sla_days,
            predicted_department=analysis.predicted_category if analysis else None,
            assigned_department=g.department_id,
            assigned_official_id=getattr(g, "assigned_official_id", None),
            assigned_official_name=assigned_off_name,
            category=g.category,
            legal_grounding_references=analysis.legal_grounding_references if analysis else None,
            ai_explanation=analysis.ai_explanation if analysis else None,
            decision_support=decision_panel,
            attachments=[
                {
                    "id": a.id,
                    "grievance_id": getattr(a, "grievance_id", g.id),
                    "attachment_type": getattr(a, "attachment_type", "voice_recording" if (a.original_filename or "").lower().endswith((".m4a", ".wav", ".mp3", ".aac", ".ogg")) else "handwritten_petition"),
                    "filename": a.original_filename or ("live_voice_petition.m4a" if (a.mime_type or "").startswith("audio/") else "evidence_document.jpg"),
                    "original_filename": a.original_filename or ("live_voice_petition.m4a" if (a.mime_type or "").startswith("audio/") else "evidence_document.jpg"),
                    "mime_type": a.mime_type or ("audio/mp4" if (a.original_filename or "").lower().endswith(".m4a") else "application/octet-stream"),
                    "storage_path": getattr(a, "storage_path", ""),
                    "file_size_bytes": getattr(a, "file_size_bytes", None),
                    "file_content_base64": getattr(a, "file_content_base64", None),
                    "raw_ocr_text": a.raw_extracted_text,
                    "raw_extracted_text": a.raw_extracted_text,
                    "extraction_status": a.extraction_status,
                    "created_at": a.created_at.isoformat() if hasattr(a.created_at, "isoformat") else str(a.created_at or ""),
                }
                for a in attachments
            ],
            audit_logs=[
                {
                    "id": l.id,
                    "actor_role": l.actor_role,
                    "action_type": l.action_type,
                    "previous_state": l.previous_state,
                    "new_state": l.new_state,
                    "remarks": l.remarks,
                    "created_at": l.created_at.isoformat() if hasattr(l.created_at, "isoformat") else str(l.created_at or ""),
                }
                for l in audit_logs
            ],
            created_at=g.created_at,
            updated_at=g.updated_at,
        )

    async def process_document_and_route(
        self, grievance_id: str, official_id: str
    ) -> OfficialGrievanceDetailResponse:
        grievance_res = await self.db.execute(
            select(Grievance).where(Grievance.id == grievance_id)
        )
        grievance = grievance_res.scalar_one_or_none()
        if not grievance:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Grievance not found.",
            )

        # 1. Fetch all uploaded attachments and extract OCR text
        atts_res = await self.db.execute(
            select(GrievanceAttachment).where(GrievanceAttachment.grievance_id == grievance_id)
        )
        attachments = atts_res.scalars().all()

        extractor = FastAutoExtractionAdapter()
        ocr_texts = []

        for att in attachments:
            if not att.raw_extracted_text and att.storage_path:
                from pathlib import Path
                path = Path(att.storage_path)
                if path.exists():
                    res = await extractor.extract_content(att, file_path=path)
                    if res.extracted_text:
                        att.raw_extracted_text = res.extracted_text
                        att.extraction_status = ExtractionStatus.COMPLETED
                        att.extraction_engine = res.engine_name
                        att.extraction_confidence = res.confidence_score
                        ocr_texts.append(res.extracted_text)
            elif att.raw_extracted_text:
                ocr_texts.append(att.raw_extracted_text)

        # Combine grievance text sources
        combined_text = " ".join(
            filter(None, [grievance.title, grievance.description, grievance.original_text] + ocr_texts)
        )

        # 2. Perform AI Analysis (Gemini LLM with Heuristic Fallback)
        from app.ai.gemini_service import GeminiGrievanceAnalyzer
        gemini_analyzer = GeminiGrievanceAnalyzer()
        gemini_result = await gemini_analyzer.analyze_grievance(combined_text)

        if gemini_result:
            category_name = gemini_result.category
            dept_name = gemini_result.department_name
            statutory_ref = gemini_result.statutory_reference
            explanation = gemini_result.reasoning
            confidence = gemini_result.confidence_score
            entities = {"key_entities": gemini_result.key_entities, "summary": gemini_result.summary}
            engine_name = "Gemini_2.5_Flash_LLM"
        else:
            routing_info = self.analyze_department_routing(combined_text)
            category_name = routing_info.category
            dept_name = routing_info.department_name
            statutory_ref = routing_info.statutory_reference
            explanation = routing_info.legal_explanation
            confidence = routing_info.confidence_score
            entities = {"text_length": len(combined_text), "matched_keywords": routing_info.matched_keywords}
            engine_name = "JanMitra_Heuristic_Rule_Engine_v1"

        # 3. Save or update GrievanceAnalysis record
        analysis_res = await self.db.execute(
            select(GrievanceAnalysis).where(GrievanceAnalysis.grievance_id == grievance_id)
        )
        analysis = analysis_res.scalar_one_or_none()

        legal_refs = {
            "statutory_act": statutory_ref,
            "confidence_score": confidence,
            "engine": engine_name,
        }

        # Multi-factor Priority Evaluation
        from app.services.priority_engine import PriorityIntelligenceEngine
        p_eval = PriorityIntelligenceEngine.evaluate(combined_text, department=dept_name)
        entities["priority_evaluation"] = {
            "priority": p_eval.priority,
            "priority_score": p_eval.priority_score,
            "sla_target_days": p_eval.sla_target_days,
            "sla_target_hours": p_eval.sla_target_hours,
            "factors": p_eval.factors,
            "rationale": p_eval.rationale,
            "rationale_ml": p_eval.rationale_ml,
        }

        if not analysis:
            analysis = GrievanceAnalysis(
                grievance_id=grievance_id,
                extracted_entities=entities,
                predicted_category=dept_name,
                legal_grounding_references=legal_refs,
                ai_explanation=explanation,
            )
            self.db.add(analysis)
        else:
            analysis.extracted_entities = entities
            analysis.predicted_category = dept_name
            analysis.legal_grounding_references = legal_refs
            analysis.ai_explanation = explanation

        # 4. Update Grievance state
        prev_status = grievance.status
        grievance.category = category_name
        grievance.department_id = dept_name
        if grievance.priority in ("high", "critical") and p_eval.priority.lower() not in ("high", "critical"):
            grievance.priority_score = max(grievance.priority_score or 75, 75)
        else:
            grievance.priority = p_eval.priority.lower()
            grievance.priority_score = p_eval.priority_score
        grievance.status = GrievanceStatus.UNDER_ANALYSIS
        grievance.updated_at = datetime.now(timezone.utc)


        # 5. Log audit trail
        audit_log = GrievanceAuditLog(
            grievance_id=grievance_id,
            actor_id=official_id,
            actor_role="official",
            action_type="DOCUMENT_PROCESSED_AND_ROUTED",
            previous_state=prev_status,
            new_state=grievance.status,
            remarks=f"Document OCR processed. Matched department: {dept_name}. Priority: {p_eval.priority} ({p_eval.priority_score}/100, SLA: {p_eval.sla_target_days}d).",
        )
        self.db.add(audit_log)
        await self.db.flush()

        return (await self.get_all_official_grievances())[0]

    async def update_official_action(
        self, grievance_id: str, official_id: str, action_in: OfficialActionRequest
    ) -> OfficialGrievanceDetailResponse:
        from sqlalchemy.orm import selectinload
        grievance_res = await self.db.execute(
            select(Grievance)
            .options(
                selectinload(Grievance.attachments),
                selectinload(Grievance.audit_logs),
                selectinload(Grievance.citizen),
                selectinload(Grievance.assigned_official),
                selectinload(Grievance.analysis),
            )
            .where(Grievance.id == grievance_id)
        )
        grievance = grievance_res.scalar_one_or_none()
        if not grievance:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Grievance not found."
            )

        prev_status = grievance.status
        prev_dept = grievance.department_id

        # 1. Update department forwarding and associated category
        if action_in.department_name:
            grievance.department_id = action_in.department_name
            dept_categories = {
                "Revenue & General Administration": "Revenue & Land Reforms",
                "Kerala Water Authority (KWA)": "Drinking Water & Public Utilities",
                "Public Works Department (PWD)": "Public Works & Roads",
                "Kerala State Electricity Board (KSEB)": "Electricity & Power Infrastructure",
                "Local Self Government Department (LSGD / Panchayat)": "Local Self Government & Sanitation",
                "Irrigation & Water Resources Department": "Irrigation & Water Resources",
            }
            for d_name, cat in dept_categories.items():
                if d_name.lower() in action_in.department_name.lower() or action_in.department_name.lower() in d_name.lower():
                    grievance.category = cat
                    break

            analysis_res = await self.db.execute(
                select(GrievanceAnalysis).where(GrievanceAnalysis.grievance_id == grievance_id)
            )
            analysis = analysis_res.scalar_one_or_none()
            if analysis:
                analysis.predicted_category = action_in.department_name

        if action_in.assigned_official_id:
            grievance.assigned_official_id = action_in.assigned_official_id

        # 2. Update grievance status
        if action_in.new_status:
            valid_statuses = {
                "forwarded", "under_processing", "clarification_required", "resolved", "closed", "under_analysis", "intake_received"
            }
            clean_status = action_in.new_status.strip().lower()
            if clean_status in valid_statuses:
                grievance.status = clean_status

        # 3. Handle official clarification question
        if action_in.question and action_in.question.strip():
            grievance.official_clarification_question = action_in.question.strip()
            grievance.status = "clarification_required"
        elif action_in.new_status == "clarification_required" and action_in.remarks:
            grievance.official_clarification_question = action_in.remarks
        elif action_in.new_status and action_in.new_status != "clarification_required":
            grievance.official_clarification_question = None

        grievance.updated_at = datetime.now(timezone.utc)

        remarks = action_in.remarks or f"Official action updated to {grievance.status}."
        if action_in.question:
            remarks += f" Clarification Question: {action_in.question}"

        action_type = "DEPARTMENT_FORWARDED" if action_in.department_name else "OFFICIAL_ACTION_SUBMITTED"

        audit_log = GrievanceAuditLog(
            grievance_id=grievance_id,
            actor_id=official_id,
            actor_role="official",
            action_type=action_type,
            previous_state=prev_status,
            new_state=grievance.status,
            remarks=remarks,
        )
        self.db.add(audit_log)

        # 4. Notify citizen of official action / status change / forwarding
        try:
            from app.models.grievance_model import UserNotification
            import uuid
            notif_title = "Official Action Executed"
            notif_type = "status_update"
            notif_msg = f"Your grievance #{grievance.grievance_number} status updated to {grievance.status.replace('_', ' ').title()}."

            if grievance.status == "clarification_required":
                notif_title = "Action Required: Official Clarification Requested"
                notif_type = "clarification_required"
                q_text = grievance.official_clarification_question or action_in.question or action_in.remarks or "Additional details requested"
                notif_msg = f"Official requested clarification on #{grievance.grievance_number}: {q_text}"
            elif action_in.new_status == "forwarded" or (action_in.department_name and action_in.department_name != prev_dept):
                notif_title = "Grievance Forwarded"
                notif_type = "forwarded"
                notif_msg = f"Your grievance #{grievance.grievance_number} has been forwarded to {action_in.department_name or grievance.department_id}."
            elif grievance.status == "resolved":
                notif_title = "Grievance Resolved"
                notif_type = "resolution"
                notif_msg = f"Your grievance #{grievance.grievance_number} has been marked resolved by authorities."
            elif grievance.status == "under_processing":
                notif_title = "Under Active Processing"
                notif_type = "status_update"
                notif_msg = f"Your grievance #{grievance.grievance_number} is now under active processing by {grievance.department_id}."

            if grievance.citizen_id:
                notif = UserNotification(
                    id=str(uuid.uuid4()),
                    user_id=grievance.citizen_id,
                    grievance_id=grievance.id,
                    title=notif_title,
                    message=notif_msg,
                    notification_type=notif_type,
                    is_read=False,
                    created_at=datetime.now(timezone.utc),
                )
                self.db.add(notif)
        except Exception as e:
            import logging
            logging.getLogger("official.service").warning(f"Citizen notification creation note: {e}")

        await self.db.commit()

        # 5. Return updated grievance detail directly in <15ms
        return await self._build_official_detail_response(grievance)

    async def get_dashboard_summary(self, department_id: Optional[str] = None) -> OfficialDashboardSummaryResponse:
        filtered = await self.search_official_grievances(department_id=department_id) if department_id else await self.get_all_official_grievances()
        total = len(filtered)

        pending_count = sum(1 for g in filtered if g.status in ("draft", "intake_received", "under_analysis"))
        under_processing_count = sum(1 for g in filtered if g.status == "under_processing")
        clarification_count = sum(1 for g in filtered if g.status == "clarification_required")
        forwarded_count = sum(1 for g in filtered if g.status == "forwarded")
        resolved_count = sum(1 for g in filtered if g.status in ("resolved", "closed"))
        high_priority_count = sum(1 for g in filtered if g.priority.lower() in ("high", "critical"))

        now_utc = datetime.now(timezone.utc)
        start_of_today = now_utc.replace(hour=0, minute=0, second=0, microsecond=0)

        def _is_today(dt: Optional[datetime]) -> bool:
            if not dt:
                return False
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt >= start_of_today

        today_count = sum(1 for g in filtered if _is_today(g.created_at))

        recent = filtered[:5]

        return OfficialDashboardSummaryResponse(
            total_grievances=total,
            pending=pending_count,
            under_processing=under_processing_count,
            clarification_required=clarification_count,
            forwarded=forwarded_count,
            resolved=resolved_count,
            high_priority=high_priority_count,
            today_received=today_count,
            recent_grievances=recent,
        )

    async def search_official_grievances(
        self,
        query: Optional[str] = None,
        status: Optional[str] = None,
        priority: Optional[str] = None,
        department_id: Optional[str] = None,
        category: Optional[str] = None,
        today_only: Optional[bool] = False,
    ) -> List[OfficialGrievanceDetailResponse]:
        from sqlalchemy.orm import selectinload
        stmt = (
            select(Grievance)
            .options(
                selectinload(Grievance.attachments),
                selectinload(Grievance.audit_logs),
                selectinload(Grievance.citizen),
                selectinload(Grievance.assigned_official),
                selectinload(Grievance.analysis),
            )
            .order_by(Grievance.created_at.desc())
        )
        res = await self.db.execute(stmt)
        raw_grievances = res.scalars().all()
        matched = []

        now_utc = datetime.now(timezone.utc)
        start_of_today = now_utc.replace(hour=0, minute=0, second=0, microsecond=0)

        for g in raw_grievances:
            if today_only:
                g_dt = g.created_at
                if not g_dt:
                    continue
                if g_dt.tzinfo is None:
                    g_dt = g_dt.replace(tzinfo=timezone.utc)
                if g_dt < start_of_today:
                    continue
            if status and g.status.lower() != status.lower():
                continue
            if priority:
                p_query = priority.lower()
                g_prio = (g.priority or "medium").lower()
                if p_query in ("high", "high_priority"):
                    if g_prio not in ("high", "critical"):
                        continue
                elif p_query == "critical":
                    if g_prio != "critical":
                        continue
                elif p_query == "medium":
                    if g_prio != "medium":
                        continue
                elif p_query == "low":
                    if g_prio != "low":
                        continue
                elif g_prio != p_query:
                    continue
            if department_id:
                assigned_dept = self.classify_grievance_department(g)
                dept_query = department_id.lower()
                is_kwa = "kwa" in dept_query or "water" in dept_query
                is_pwd = "pwd" in dept_query or "works" in dept_query or "road" in dept_query
                is_kseb = "kseb" in dept_query or "electricity" in dept_query or "power" in dept_query
                is_lsgd = "lsgd" in dept_query or "panchayat" in dept_query or "municipality" in dept_query
                is_rev = "revenue" in dept_query or "admin" in dept_query

                match = (
                    (assigned_dept.lower() == department_id.lower())
                    or (is_kwa and assigned_dept == "Kerala Water Authority (KWA)")
                    or (is_pwd and assigned_dept == "Public Works Department (PWD)")
                    or (is_kseb and assigned_dept == "Kerala State Electricity Board (KSEB)")
                    or (is_lsgd and assigned_dept == "Local Self Government Department (LSGD / Panchayat)")
                    or (is_rev and assigned_dept == "Revenue & General Administration")
                )

                if not match:
                    continue
            if category and g.category and category.lower() not in g.category.lower():
                continue
            if query and query.strip():
                q = query.strip().lower()
                citizen_name = g.citizen.full_name.lower() if g.citizen else ""
                text_match = (
                    q in g.id.lower()
                    or q in (g.title or "").lower()
                    or q in (g.description or "").lower()
                    or q in g.grievance_number.lower()
                    or q in (g.original_text or "").lower()
                    or q in citizen_name
                )
                if not text_match:
                    continue
            matched.append(g)

        if priority:
            matched.sort(
                key=lambda x: (
                    x.priority_score if x.priority_score is not None else 50,
                    x.created_at.timestamp() if hasattr(x.created_at, "timestamp") else 0.0,
                ),
                reverse=True,
            )

        return [await self._build_official_detail_response(g) for g in matched]

    async def get_attention_queue(self, department_id: Optional[str] = None) -> List[OfficialGrievanceDetailResponse]:
        all_grievances = await self.search_official_grievances(department_id=department_id) if department_id else await self.get_all_official_grievances()

        def attention_sort_key(g: OfficialGrievanceDetailResponse):
            base_score = g.priority_score if g.priority_score is not None else 50
            if g.status == "clarification_required":
                base_score += 5
            ts = g.created_at.timestamp() if hasattr(g.created_at, "timestamp") else 0.0
            return (base_score, -ts)

        sorted_queue = sorted(all_grievances, key=attention_sort_key, reverse=True)
        return sorted_queue

    @staticmethod
    def classify_grievance_department(g: Grievance) -> str:
        """Deterministically classifies every grievance to a valid statutory department without dropping unassigned records."""
        # 1. Explicit department_id if present
        raw = (g.department_id or "").strip()
        if raw:
            r_lower = raw.lower()
            if "water" in r_lower or "kwa" in r_lower:
                return "Kerala Water Authority (KWA)"
            if "pwd" in r_lower or "road" in r_lower or "works" in r_lower or "bridge" in r_lower:
                return "Public Works Department (PWD)"
            if "kseb" in r_lower or "power" in r_lower or "electric" in r_lower:
                return "Kerala State Electricity Board (KSEB)"
            if "lsgd" in r_lower or "panchayat" in r_lower or "municipality" in r_lower or "corporation" in r_lower or "waste" in r_lower or "garbage" in r_lower or "drain" in r_lower:
                return "Local Self Government Department (LSGD / Panchayat)"
            if "revenue" in r_lower or "admin" in r_lower or "land" in r_lower or "survey" in r_lower:
                return "Revenue & General Administration"

        # 2. Predicted category from AI analysis
        pred = (g.analysis.predicted_category if g.analysis else "") or ""
        if pred:
            p_lower = pred.lower()
            if "water" in p_lower or "kwa" in p_lower:
                return "Kerala Water Authority (KWA)"
            if "pwd" in p_lower or "road" in p_lower or "works" in p_lower:
                return "Public Works Department (PWD)"
            if "kseb" in p_lower or "power" in p_lower or "electric" in p_lower:
                return "Kerala State Electricity Board (KSEB)"
            if "lsgd" in p_lower or "panchayat" in p_lower or "waste" in p_lower or "sanitation" in p_lower or "drain" in p_lower:
                return "Local Self Government Department (LSGD / Panchayat)"
            if "revenue" in p_lower or "admin" in p_lower or "land" in p_lower:
                return "Revenue & General Administration"

        # 3. Category / Title / Original Text keyword hints
        category = g.category or ""
        title = g.title or ""
        desc = g.description or ""
        orig = g.original_text or ""
        content = f"{category} {title} {desc} {orig}".lower()
        if any(k in content for k in ("water", "kwa", "pipe", "leak", "വെള്ളം", "പൈപ്പ്", "കുടിവെള്ളം")):
            return "Kerala Water Authority (KWA)"
        if any(k in content for k in ("road", "pwd", "pothole", "tar", "bridge", "റോഡ്", "കുഴി", "ടാർ")):
            return "Public Works Department (PWD)"
        if any(k in content for k in ("kseb", "electricity", "power", "voltage", "current", "വൈദ്യുതി", "കറണ്ട്", "പോസ്റ്റ്")):
            return "Kerala State Electricity Board (KSEB)"
        if any(k in content for k in ("panchayat", "lsgd", "waste", "garbage", "drainage", "മാലിന്യം", "പഞ്ചായത്ത്", "ഓട")):
            return "Local Self Government Department (LSGD / Panchayat)"

        # 4. Fallback: all unassigned / general petitions belong to Revenue & General Administration (Nodal Department)
        return "Revenue & General Administration"

    async def get_department_workload(self) -> List[DepartmentWorkloadResponse]:
        from sqlalchemy.orm import selectinload
        stmt = (
            select(Grievance)
            .options(selectinload(Grievance.analysis))
        )
        res = await self.db.execute(stmt)
        all_grievances = res.scalars().all()

        depts = [
            "Kerala Water Authority (KWA)",
            "Public Works Department (PWD)",
            "Kerala State Electricity Board (KSEB)",
            "Local Self Government Department (LSGD / Panchayat)",
            "Revenue & General Administration",
        ]

        dept_groups = {d: [] for d in depts}
        for g in all_grievances:
            assigned_dept = self.classify_grievance_department(g)
            dept_groups[assigned_dept].append(g)

        workloads = []
        for d in depts:
            dept_g = dept_groups[d]
            pending = sum(1 for g in dept_g if g.status in ("draft", "intake_received", "under_analysis"))
            under_proc = sum(1 for g in dept_g if g.status == "under_processing")
            clarification = sum(1 for g in dept_g if g.status == "clarification_required")
            forwarded = sum(1 for g in dept_g if g.status == "forwarded")
            resolved = sum(1 for g in dept_g if g.status in ("resolved", "closed"))

            workloads.append(
                DepartmentWorkloadResponse(
                    department_name=d,
                    pending=pending,
                    under_processing=under_proc,
                    clarification_required=clarification,
                    forwarded=forwarded,
                    resolved=resolved,
                    total=len(dept_g),
                )
            )

        return workloads

    async def get_all_official_users(self) -> List[Dict[str, Any]]:
        stmt = select(User).where(User.role == "official").order_by(User.full_name.asc())
        res = await self.db.execute(stmt)
        users = res.scalars().all()
        return [
            {
                "id": u.id,
                "full_name": u.full_name,
                "email": u.email,
                "phone": u.phone,
                "role": u.role,
                "department_id": u.department_id or "Kerala Water Authority (KWA)",
                "is_active": u.is_active,
            }
            for u in users
        ]

    async def get_all_citizen_users(self) -> List[Dict[str, Any]]:
        from sqlalchemy import func
        stmt = select(User).where(User.role == "citizen").order_by(User.created_at.asc())
        res = await self.db.execute(stmt)
        users = res.scalars().all()
        results = []
        for u in users:
            g_stmt = select(func.count(Grievance.id)).where(Grievance.citizen_id == u.id)
            g_res = await self.db.execute(g_stmt)
            count = g_res.scalar() or 0
            results.append({
                "id": u.id,
                "full_name": u.full_name,
                "email": u.email,
                "phone": u.phone,
                "role": u.role,
                "grievance_count": count,
                "created_at": u.created_at.isoformat() if u.created_at else None,
            })
        return results

    async def update_official_user_status(
        self, user_id: str, is_active: Optional[bool] = None, department_id: Optional[str] = None
    ) -> Dict[str, Any]:
        stmt = select(User).where(User.id == user_id)
        res = await self.db.execute(stmt)
        user = res.scalar_one_or_none()
        if not user:
            raise ValueError(f"Official user {user_id} not found.")

        if is_active is not None:
            user.is_active = is_active
        if department_id is not None:
            user.department_id = department_id

        await self.db.commit()
        await self.db.refresh(user)
        return {
            "id": user.id,
            "full_name": user.full_name,
            "email": user.email,
            "department_id": user.department_id,
            "is_active": user.is_active,
        }

