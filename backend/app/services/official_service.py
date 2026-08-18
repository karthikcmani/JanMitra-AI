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
    category: Optional[str] = None
    legal_grounding_references: Optional[Dict[str, Any]] = None
    ai_explanation: Optional[str] = None
    attachments: List[Dict[str, Any]] = []
    audit_logs: List[Dict[str, Any]] = []
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class OfficialActionRequest(BaseModel):
    department_name: Optional[str] = Field(None, max_length=150)
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
                    category=g.category,
                    legal_grounding_references=analysis.legal_grounding_references if analysis else None,
                    ai_explanation=analysis.ai_explanation if analysis else None,
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
                            "created_at": l.created_at,
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

        # 2. Perform Department Routing Analysis
        routing_info = self.analyze_department_routing(combined_text)

        # 3. Save or update GrievanceAnalysis record
        analysis_res = await self.db.execute(
            select(GrievanceAnalysis).where(GrievanceAnalysis.grievance_id == grievance_id)
        )
        analysis = analysis_res.scalar_one_or_none()

        legal_refs = {
            "statutory_act": routing_info.statutory_reference,
            "matched_keywords": routing_info.matched_keywords,
            "confidence_score": routing_info.confidence_score,
            "engine": "JanMitra_RAG_Legal_Engine_v1",
        }

        if not analysis:
            analysis = GrievanceAnalysis(
                grievance_id=grievance_id,
                extracted_entities={"text_length": len(combined_text)},
                predicted_category=routing_info.department_name,
                legal_grounding_references=legal_refs,
                ai_explanation=routing_info.legal_explanation,
            )
            self.db.add(analysis)
        else:
            analysis.predicted_category = routing_info.department_name
            analysis.legal_grounding_references = legal_refs
            analysis.ai_explanation = routing_info.legal_explanation

        # 4. Update Grievance state
        prev_status = grievance.status
        grievance.category = routing_info.category
        grievance.department_id = routing_info.department_name
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

        if action_in.new_status:
            grievance.status = action_in.new_status

        grievance.updated_at = datetime.now(timezone.utc)

        remarks = action_in.remarks or f"Official action updated to {grievance.status}."
        if action_in.question:
            remarks += f" Clarification Question: {action_in.question}"

        audit_log = GrievanceAuditLog(
            grievance_id=grievance_id,
            actor_id=official_id,
            actor_role="official",
            action_type="OFFICIAL_ACTION_SUBMITTED",
            previous_state=prev_status,
            new_state=grievance.status,
            remarks=remarks,
        )
        self.db.add(audit_log)
        await self.db.commit()

        grievances = await self.get_all_official_grievances()
        matched = [g for g in grievances if g.id == grievance_id]
        return matched[0] if matched else grievances[0]
