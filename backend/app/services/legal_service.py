import logging
from typing import Any, Dict, List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.grievance_model import Grievance, GrievanceAnalysis
from app.services.knowledge_service import KnowledgeBaseService

logger = logging.getLogger(__name__)


class LegalIntelligenceService:
    """RAG-based Legal Intelligence Pipeline for Public Grievances.

    Retrieves statutory provisions, government orders, and circulars grounded in official sources.
    Maintains explicit human supervision boundary (Advisory Legal Intelligence).
    """

    def __init__(self, db: AsyncSession):
        self.db = db
        self.kb_service = KnowledgeBaseService(db)

    async def analyze_legal_grounding(self, grievance_id: str) -> Dict[str, Any]:
        """Performs RAG retrieval over government documents for a grievance."""
        g_res = await self.db.execute(select(Grievance).where(Grievance.id == grievance_id))
        grievance = g_res.scalar_one_or_none()
        if not grievance:
            raise ValueError(f"Grievance '{grievance_id}' not found.")

        ocr_texts = [att.raw_extracted_text for att in grievance.attachments if att.raw_extracted_text]
        combined_text = " ".join(
            filter(None, [grievance.title, grievance.description, grievance.original_text, grievance.translated_text] + ocr_texts)
        ).strip()

        if not combined_text:
            return {
                "grievance_id": grievance_id,
                "status": "FAILED",
                "message": "No text available for legal analysis.",
                "retrieved_sources": [],
                "legal_considerations": [],
            }

        # 1. Retrieve top matching government document chunks
        relevant_chunks = await self.kb_service.search_relevant_chunks(combined_text, top_k=4)

        # 2. Formulate evidence-grounded legal considerations
        legal_considerations = []
        retrieved_sources = []
        required_documents = ["Proof of identity (Aadhaar / Voter ID)", "Grievance site photograph"]

        category_lower = (grievance.category or combined_text).lower()

        if any(k in category_lower for k in ["revenue", "land", "പുറമ്പോക്ക്", "കയ്യേറ്റം", "തോട്", "poramboke", "encroachment", "survey", "താലൂക്ക്"]):
            required_documents.extend([
                "Land Tax receipt / Thandaper extract (if private adjoining plot)",
                "Re-survey sketch / Location sketch of poramboke canal site",
                "Geo-tagged photographs of canal obstruction or encroachment",
            ])
        elif ("water" in category_lower or "kwa" in category_lower or "pipe" in category_lower) and not any(k in category_lower for k in ["തോട്", "canal", "encroachment", "പുറമ്പോക്ക്"]):
            required_documents.extend(["KWA Consumer Number / Bill copy", "Recent water supply status note"])
        elif "road" in category_lower or "pothole" in category_lower or "drain" in category_lower or "pwd" in category_lower:
            required_documents.extend(["Geo-tagged photograph of damaged road", "Ward member endorsement letter"])
        elif "electric" in category_lower or "kseb" in category_lower or "pole" in category_lower:
            required_documents.extend(["KSEB Consumer Number", "Photograph of leaning pole or wire hazard"])
        elif "waste" in category_lower or "garbage" in category_lower or "sanitation" in category_lower or "panchayat" in category_lower:
            required_documents.extend(["Photograph of waste dump site", "Ward Member representation copy"])

        for item in relevant_chunks:
            retrieved_sources.append({
                "document_title": item["document_title"],
                "act_or_go_no": item["act_number_or_go_no"],
                "department": item["department"],
                "section": item["section_title"],
                "excerpt": item["chunk_text"],
                "relevance_score": item["similarity_score"],
            })

            legal_considerations.append({
                "provision_title": item["section_title"],
                "statutory_authority": item["department"],
                "legal_relevance": f"Grounds under {item['document_title']}: Mandates administrative inspection and timely grievance redressal.",
                "applicable_rule": item["chunk_text"][:200] + "...",
            })

        category_lower = (grievance.category or combined_text).lower()
        top_act = None

        if any(k in category_lower for k in ["revenue", "land", "പുറമ്പോക്ക്", "കയ്യേറ്റം", "തോട്", "poramboke", "encroachment", "survey", "താലൂക്ക്", "തഹസിൽദാർ"]):
            top_act = "Kerala Land Conservancy Act, 1957 (Sections 3, 7 & 11)"
        elif any(k in category_lower for k in ["കുടിവെള്ളം", "പൈപ്പ്", "വാട്ടർ അതോറിറ്റി", "drinking water", "kwa"]):
            top_act = "Kerala Water Supply and Sewerage Act, 1986 (Section 14)"
        elif any(k in category_lower for k in ["റോഡ്", "പൊതുമരാമത്ത്", "pwd", "highway", "pothole"]):
            top_act = "Kerala Highway Protection Act, 1999 (Section 7)"
        elif any(k in category_lower for k in ["വൈദ്യുതി", "kseb", "electric", "power", "transformer"]):
            top_act = "Electricity Act, 2003 (Section 43) & Kerala Electricity Supply Code, 2014"
        elif any(k in category_lower for k in ["പഞ്ചായത്ത്", "മാലിന്യം", "panchayat", "waste", "sanitation"]):
            top_act = "Kerala Panchayat Raj Act, 1994 (Section 166 & 218)"

        if not top_act:
            for src in retrieved_sources:
                if "Land Conservancy" in src.get("document_title", ""):
                    top_act = "Kerala Land Conservancy Act, 1957 (Sections 3, 7 & 11)"
                    break
                elif "Water Authority" in src.get("document_title", ""):
                    top_act = "Kerala Water Supply and Sewerage Act, 1986 (Section 14)"
                    break
                elif "Panchayat Raj" in src.get("document_title", ""):
                    top_act = "Kerala Panchayat Raj Act, 1994 (Section 166)"
                    break

        if not top_act and retrieved_sources:
            top_act = retrieved_sources[0]["document_title"]

        result_payload = {
            "grievance_id": grievance_id,
            "status": "COMPLETED",
            "statutory_act": top_act or "Kerala Land Conservancy Act, 1957 (Sections 3, 7 & 11)",
            "legal_considerations": legal_considerations,
            "retrieved_sources": retrieved_sources,
            "required_documents": list(set(required_documents)),
            "disclaimer": "This analysis presents possible statutory considerations derived from official government orders and Acts. It serves as administrative decision support for government officers and does not constitute a legal judicial decree.",
        }

        # 3. Save or update GrievanceAnalysis persistent entity
        analysis_res = await self.db.execute(
            select(GrievanceAnalysis).where(GrievanceAnalysis.grievance_id == grievance_id)
        )
        analysis_record = analysis_res.scalar_one_or_none()
        if not analysis_record:
            analysis_record = GrievanceAnalysis(
                grievance_id=grievance_id,
                legal_grounding_references=result_payload,
                ai_explanation="RAG legal intelligence completed successfully.",
            )
            self.db.add(analysis_record)
        else:
            merged = dict(analysis_record.legal_grounding_references or {})
            merged.update(result_payload)
            if top_act:
                merged["statutory_act"] = top_act
            analysis_record.legal_grounding_references = merged
            analysis_record.ai_explanation = "RAG legal intelligence refreshed."

        await self.db.commit()
        return result_payload
