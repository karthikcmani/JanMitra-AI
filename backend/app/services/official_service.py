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
    title: Optional[str] = None
    description: Optional[str] = None
    intake_mode: str
    original_language: str
    original_text: Optional[str] = None
    raw_ocr_text: Optional[str] = None
    status: str
    priority: str
    predicted_department: Optional[str] = None
    assigned_department: Optional[str] = None
    assigned_official_id: Optional[str] = None
    assigned_official_name: Optional[str] = None
    category: Optional[str] = None
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
            "code": "KWA",
            "name": "Kerala Water Authority (KWA)",
            "category": "Water Supply & Drainage",
            "keywords": ["കുടിവെള്ളം", "പൈപ്പ്", "വെള്ളം", "വാർഡ്", "water", "pipe", "leak", "kwa", "drainage"],
            "statutory_reference": "Kerala Water Supply and Sewerage Act, 1986 (Section 14)",
            "legal_explanation": "Complaint relates to public drinking water supply interruption or pipe damage under KWA jurisdiction.",
        },
        {
            "code": "PWD",
            "name": "Public Works Department (PWD)",
            "category": "Roads & Public Infrastructure",
            "keywords": ["റോഡ്", "പണി", "കലുങ്ക്", "പാലം", "കുഴി", "road", "pothole", "bridge", "pwd", "highway"],
            "statutory_reference": "Kerala Highway Protection Act, 1999 (Section 7)",
            "legal_explanation": "Complaint involves road maintenance, pothole repair, or culvert construction under PWD oversight.",
        },
        {
            "code": "KSEB",
            "name": "Kerala State Electricity Board (KSEB)",
            "category": "Power & Electricity",
            "keywords": ["വൈദ്യുതി", "ട്രാൻസ്ഫോർമർ", "പോസ്റ്റ്", "സ്ട്രീറ്റ് ലൈറ്റ്", "power", "electricity", "kseb", "light", "transformer"],
            "statutory_reference": "Electricity Act, 2003 (Section 43)",
            "legal_explanation": "Complaint pertains to power outages, damaged electricity poles, or transformer faults managed by KSEB.",
        },
        {
            "code": "LSGD",
            "name": "Local Self Government Department (LSGD / Panchayat)",
            "category": "Local Body & Public Health",
            "keywords": ["മാലിന്യം", "പഞ്ചായത്ത്", "മുനിസിപ്പാലിറ്റി", "വീട്ടുനികുതി", "waste", "sanitation", "panchayat", "municipality", "cleanliness"],
            "statutory_reference": "Kerala Panchayat Raj Act, 1994 (Section 166)",
            "legal_explanation": "Complaint involves local ward sanitation, municipal waste management, or Grama Panchayat civic services.",
        },
    ]

    def __init__(self, db: AsyncSession):
        self.db = db
        self.repo = GrievanceRepository(db)

    def analyze_department_routing(self, text: str) -> DepartmentRoutingInfo:
        text_lower = (text or "").lower()
        best_match = None
        highest_score = 0
        matched_kw = []

        for rule in self.DEPARTMENT_RULES:
            matches = [kw for kw in rule["keywords"] if kw.lower() in text_lower]
            score = len(matches)
            if score > highest_score:
                highest_score = score
                best_match = rule
                matched_kw = matches

        if best_match and highest_score > 0:
            confidence = min(0.70 + (highest_score * 0.10), 0.98)
            return DepartmentRoutingInfo(
                department_code=best_match["code"],
                department_name=best_match["name"],
                category=best_match["category"],
                confidence_score=confidence,
                matched_keywords=matched_kw,
                statutory_reference=best_match["statutory_reference"],
                legal_explanation=best_match["legal_explanation"],
            )

        # Default fallback to Revenue & General Administration
        return DepartmentRoutingInfo(
            department_code="REV",
            department_name="Revenue & General Administration",
            category="General Public Grievance",
            confidence_score=0.75,
            matched_keywords=[],
            statutory_reference="Kerala Public Services Act, 2012 (Section 4)",
            legal_explanation="Grievance received for administrative review and departmental routing assignment.",
        )

    async def get_all_official_grievances(self) -> List[OfficialGrievanceDetailResponse]:
        stmt = select(Grievance).order_by(Grievance.created_at.desc())
        res = await self.db.execute(stmt)
        grievances = res.scalars().all()

        results = []
        for g in grievances:
            # Fetch citizen user details
            citizen_res = await self.db.execute(select(User).where(User.id == g.citizen_id))
            citizen = citizen_res.scalar_one_or_none()

            assigned_off_name = None
            if getattr(g, "assigned_official_id", None):
                off_res = await self.db.execute(select(User).where(User.id == g.assigned_official_id))
                off_user = off_res.scalar_one_or_none()
                if off_user:
                    assigned_off_name = off_user.full_name

            # Fetch attachments
            atts_res = await self.db.execute(
                select(GrievanceAttachment).where(GrievanceAttachment.grievance_id == g.id)
            )
            attachments = atts_res.scalars().all()

            # Aggregate raw OCR text
            raw_ocr = "\n".join(
                [a.raw_extracted_text for a in attachments if a.raw_extracted_text]
            )

            # Fetch analysis
            analysis_res = await self.db.execute(
                select(GrievanceAnalysis).where(GrievanceAnalysis.grievance_id == g.id)
            )
            analysis = analysis_res.scalar_one_or_none()

            # Fetch audit logs
            logs_res = await self.db.execute(
                select(GrievanceAuditLog)
                .where(GrievanceAuditLog.grievance_id == g.id)
                .order_by(GrievanceAuditLog.created_at.asc())
            )
            audit_logs = logs_res.scalars().all()

            # Build Decision Support Panel
            dept_suggestion = g.department_id or (analysis.predicted_category if analysis else "Revenue & General Administration")
            statutory_info = analysis.legal_grounding_references.get("statutory_act", "Kerala Public Services Act, 2012") if (analysis and analysis.legal_grounding_references) else "Kerala Public Services Act, 2012"
            explanation_text = analysis.ai_explanation if (analysis and analysis.ai_explanation) else "Assigned based on natural language petition context."
            confidence_val = float(analysis.legal_grounding_references.get("confidence_score", 0.85)) if (analysis and analysis.legal_grounding_references) else 0.85

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

            decision_panel = AIDecisionSupportPanel(
                suggested_department=dept_suggestion,
                priority=g.priority,
                reasoning=explanation_text,
                key_facts=[f"Category: {g.category or 'General'}", f"Language: {g.original_language}"],
                statutory_relevance=statutory_info,
                missing_information=missing_info,
                suggested_next_step=next_step,
                confidence_score=confidence_val,
            )

            results.append(
                OfficialGrievanceDetailResponse(
                    id=g.id,
                    grievance_number=g.grievance_number,
                    citizen_id=g.citizen_id,
                    citizen_name=citizen.full_name if citizen else "Citizen User",
                    citizen_phone=citizen.phone if citizen else None,
                    title=g.title,
                    description=g.description,
                    intake_mode=g.intake_mode,
                    original_language=g.original_language,
                    original_text=g.original_text,
                    raw_ocr_text=raw_ocr if raw_ocr else g.original_text,
                    status=g.status,
                    priority=g.priority,
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
                            "filename": a.original_filename,
                            "mime_type": a.mime_type,
                            "raw_ocr_text": a.raw_extracted_text,
                            "extraction_status": a.extraction_status,
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
                            "created_at": l.created_at.isoformat(),
                        }
                        for l in audit_logs
                    ],
                    created_at=g.created_at,
                    updated_at=g.updated_at,
                )
            )
        return results

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
            remarks=f"Document OCR processed. Automatically matched department: {routing_info.department_name}.",
        )
        self.db.add(audit_log)
        await self.db.commit()

        return (await self.get_all_official_grievances())[0]

    async def update_official_action(
        self, grievance_id: str, official_id: str, action_in: OfficialActionRequest
    ) -> OfficialGrievanceDetailResponse:
        grievance_res = await self.db.execute(
            select(Grievance).where(Grievance.id == grievance_id)
        )
        grievance = grievance_res.scalar_one_or_none()
        if not grievance:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Grievance not found."
            )

        prev_status = grievance.status

        if action_in.department_name:
            grievance.department_id = action_in.department_name

        if action_in.assigned_official_id:
            grievance.assigned_official_id = action_in.assigned_official_id

        if action_in.new_status:
            grievance.status = action_in.new_status

        grievance.updated_at = datetime.now(timezone.utc)

        remarks = action_in.remarks or f"Official action updated to {grievance.status}."
        if action_in.question:
            remarks += f" Clarification Question: {action_in.question}"

        action_type = "ADMINISTRATIVE_ASSIGNMENT_EXECUTED" if (action_in.department_name or action_in.assigned_official_id) else "OFFICIAL_ACTION_SUBMITTED"

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
        await self.db.commit()

        grievances = await self.get_all_official_grievances()
        matched = [g for g in grievances if g.id == grievance_id]
        return matched[0] if matched else grievances[0]

    async def get_dashboard_summary(self) -> OfficialDashboardSummaryResponse:
        all_grievances = await self.get_all_official_grievances()
        total = len(all_grievances)

        pending_count = sum(1 for g in all_grievances if g.status in ("draft", "intake_received", "under_analysis"))
        under_processing_count = sum(1 for g in all_grievances if g.status == "under_processing")
        clarification_count = sum(1 for g in all_grievances if g.status == "clarification_required")
        forwarded_count = sum(1 for g in all_grievances if g.status == "forwarded")
        resolved_count = sum(1 for g in all_grievances if g.status in ("resolved", "closed"))
        high_priority_count = sum(1 for g in all_grievances if g.priority.lower() in ("high", "critical"))

        start_of_today = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
        today_count = sum(1 for g in all_grievances if g.created_at >= start_of_today)

        recent = all_grievances[:5]

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
    ) -> List[OfficialGrievanceDetailResponse]:
        all_grievances = await self.get_all_official_grievances()
        filtered = []

        for g in all_grievances:
            if status and g.status.lower() != status.lower():
                continue
            if priority and g.priority.lower() != priority.lower():
                continue
            if department_id:
                dept_target = f"{g.assigned_department or ''} {g.predicted_department or ''}".lower()
                dept_query = department_id.lower()
                is_kwa = "kwa" in dept_query or "water" in dept_query
                is_pwd = "pwd" in dept_query or "works" in dept_query or "road" in dept_query
                is_kseb = "kseb" in dept_query or "electricity" in dept_query or "power" in dept_query
                is_lsgd = "lsgd" in dept_query or "panchayat" in dept_query or "municipality" in dept_query
                is_rev = "revenue" in dept_query or "admin" in dept_query

                match = (dept_query in dept_target) or \
                        (is_kwa and ("kwa" in dept_target or "water" in dept_target)) or \
                        (is_pwd and ("pwd" in dept_target or "road" in dept_target or "works" in dept_target)) or \
                        (is_kseb and ("kseb" in dept_target or "power" in dept_target or "electricity" in dept_target)) or \
                        (is_lsgd and ("lsgd" in dept_target or "panchayat" in dept_target)) or \
                        (is_rev and ("revenue" in dept_target or "admin" in dept_target))

                if not match:
                    continue
            if category and g.category and category.lower() not in g.category.lower():
                continue
            if query and query.strip():
                q = query.strip().lower()
                text_match = (
                    q in (g.title or "").lower()
                    or q in (g.description or "").lower()
                    or q in g.grievance_number.lower()
                    or q in (g.original_text or "").lower()
                    or q in (g.citizen_name or "").lower()
                )
                if not text_match:
                    continue
            filtered.append(g)

        return filtered

    async def get_attention_queue(self) -> List[OfficialGrievanceDetailResponse]:
        all_grievances = await self.get_all_official_grievances()

        def attention_sort_key(g: OfficialGrievanceDetailResponse):
            priority_score = 0
            if g.priority.lower() in ("critical", "high"):
                priority_score = 3
            elif g.status == "clarification_required":
                priority_score = 2
            elif g.status in ("under_analysis", "intake_received"):
                priority_score = 1

            return (priority_score, -g.created_at.timestamp())

        sorted_queue = sorted(all_grievances, key=attention_sort_key, reverse=True)
        return sorted_queue

    async def get_department_workload(self) -> List[DepartmentWorkloadResponse]:
        all_grievances = await self.get_all_official_grievances()
        depts = [
            "Kerala Water Authority (KWA)",
            "Public Works Department (PWD)",
            "Kerala State Electricity Board (KSEB)",
            "Local Self Government Department (LSGD / Panchayat)",
            "Revenue & General Administration",
        ]

        workloads = []
        for d in depts:
            dept_g = [g for g in all_grievances if g.assigned_department == d or g.predicted_department == d]
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

        await self.db.flush()
        return {
            "id": user.id,
            "full_name": user.full_name,
            "email": user.email,
            "department_id": user.department_id,
            "is_active": user.is_active,
        }

