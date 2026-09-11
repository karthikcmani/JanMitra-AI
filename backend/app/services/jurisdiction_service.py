import logging
from datetime import datetime, timezone
from typing import Any, Dict, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.grievance_model import Grievance, GrievanceAuditLog, JurisdictionRecommendation

logger = logging.getLogger(__name__)

AUTHORITY_MAPPINGS = [
    {
        "keywords": ["water", "pipe", "leak", "kwa", "drinking water", "കുടിവെള്ളം", "പൈപ്പ്"],
        "department": "Kerala Water Authority (KWA)",
        "authority": "KWA Assistant Executive Engineer, Water Works Sub-Division",
        "level": "DEPARTMENTAL_SUBDIVISION",
    },
    {
        "keywords": ["electric", "pole", "wire", "kseb", "power", "transformer", "വൈദ്യുതി", "പോസ്റ്റ്"],
        "department": "Kerala State Electricity Board (KSEB)",
        "authority": "KSEB Assistant Engineer, Electrical Section Office",
        "level": "SECTION_OFFICE",
    },
    {
        "keywords": ["highway", "pwd", "state road", "bridge", "റോഡ്", "പാലം"],
        "department": "Public Works Department (PWD)",
        "authority": "PWD Roads Division Executive Engineer",
        "level": "DISTRICT_DIVISION",
    },
    {
        "keywords": ["waste", "garbage", "sanitation", "drain", "panchayat", "ward", "പഞ്ചായത്ത്", "ശുചിത്വം"],
        "department": "Local Self Government Department (LSGD)",
        "authority": "Grama Panchayat Secretary & LSGD Assistant Engineer",
        "level": "PANCHAYAT",
    },
    {
        "keywords": ["land", "revenue", "pattayam", "encroachment", "survey", "താലൂക്ക്", "വില്ലേജ്"],
        "department": "Revenue & Land Reforms Department",
        "authority": "Tahsildar / Village Officer, Revenue Department",
        "level": "TALUK_VILLAGE",
    },
]


class JurisdictionIntelligenceService:
    """Jurisdiction Intelligence & Administrative Authority Recommendation Engine."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def recommend_jurisdiction(self, grievance_id: str) -> Dict[str, Any]:
        """Analyzes confirmed location & grievance classification to recommend competent authority."""
        g_res = await self.db.execute(select(Grievance).where(Grievance.id == grievance_id))
        grievance = g_res.scalar_one_or_none()
        if not grievance:
            raise ValueError(f"Grievance '{grievance_id}' not found.")

        location = grievance.confirmed_location or {}
        district = location.get("district", "Ernakulam")
        ward = location.get("ward", "General Ward")
        local_body = location.get("panchayat") or location.get("municipality") or location.get("corporation") or "Local Authority"

        ocr_texts = [att.raw_extracted_text for att in grievance.attachments if att.raw_extracted_text]
        combined_text = " ".join(
            filter(None, [grievance.title, grievance.description, grievance.original_text, grievance.category] + ocr_texts)
        ).lower()

        matched_dept = "Local Self Government Department (LSGD)"
        matched_auth = f"{local_body} Secretary & Ward Officer, Ward #{ward}"
        matched_level = "LOCAL_BODY"
        confidence = 0.88

        for rule in AUTHORITY_MAPPINGS:
            if any(k in combined_text for k in rule["keywords"]):
                matched_dept = rule["department"]
                matched_auth = f"{rule['authority']} ({district} District - {local_body})"
                matched_level = rule["level"]
                confidence = 0.94
                break

        reasoning = (
            f"Authority derived based on verified location '{local_body}, Ward #{ward}, {district}' "
            f"and issue subject analysis. Recommended primary administrative office: {matched_dept}."
        )

        # Persist or update JurisdictionRecommendation
        rec_res = await self.db.execute(
            select(JurisdictionRecommendation).where(JurisdictionRecommendation.grievance_id == grievance_id)
        )
        rec = rec_res.scalar_one_or_none()
        if not rec:
            rec = JurisdictionRecommendation(
                grievance_id=grievance_id,
                recommended_authority=matched_auth,
                department_name=matched_dept,
                jurisdiction_level=matched_level,
                location_used={"district": district, "local_body": local_body, "ward": ward},
                reasoning=reasoning,
                confidence_score=confidence,
                status="RECOMMENDED",
            )
            self.db.add(rec)
        else:
            rec.recommended_authority = matched_auth
            rec.department_name = matched_dept
            rec.jurisdiction_level = matched_level
            rec.location_used = {"district": district, "local_body": local_body, "ward": ward}
            rec.reasoning = reasoning
            rec.confidence_score = confidence

        # Assign department_id on grievance if not set
        if not grievance.department_id:
            grievance.department_id = matched_dept

        await self.db.commit()

        return {
            "grievance_id": grievance_id,
            "recommended_authority": rec.recommended_authority,
            "department_name": rec.department_name,
            "jurisdiction_level": rec.jurisdiction_level,
            "location_used": rec.location_used,
            "reasoning": rec.reasoning,
            "confidence_score": rec.confidence_score,
            "status": rec.status,
            "human_override_remarks": rec.human_override_remarks,
        }

    async def override_recommendation(
        self, grievance_id: str, official_id: str, new_department: str, new_authority: str, remarks: str
    ) -> Dict[str, Any]:
        """Allows Admin / Official to confirm or override jurisdiction recommendation."""
        rec_res = await self.db.execute(
            select(JurisdictionRecommendation).where(JurisdictionRecommendation.grievance_id == grievance_id)
        )
        rec = rec_res.scalar_one_or_none()
        if not rec:
            rec = JurisdictionRecommendation(grievance_id=grievance_id, reasoning="Manual Override")
            self.db.add(rec)

        rec.department_name = new_department
        rec.recommended_authority = new_authority
        rec.status = "OVERRIDDEN"
        rec.human_override_remarks = remarks

        # Update grievance assigned department
        g_res = await self.db.execute(select(Grievance).where(Grievance.id == grievance_id))
        grievance = g_res.scalar_one_or_none()
        if grievance:
            grievance.department_id = new_department

        audit = GrievanceAuditLog(
            grievance_id=grievance_id,
            actor_id=official_id,
            actor_role="official",
            action_type="JURISDICTION_OVERRIDDEN",
            remarks=f"Jurisdiction overridden to {new_department} ({new_authority}). Remarks: {remarks}",
        )
        self.db.add(audit)
        await self.db.commit()

        return {
            "status": "success",
            "department_name": new_department,
            "recommended_authority": new_authority,
            "remarks": remarks,
        }
