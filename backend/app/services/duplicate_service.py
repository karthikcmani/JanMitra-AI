import logging
from typing import Any, Dict, List
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.grievance_model import DuplicateDetection, Grievance
from app.services.knowledge_service import compute_vector, cosine_similarity

logger = logging.getLogger(__name__)


class DuplicateDetectionService:
    """Duplicate and Similar Grievance Detection Engine.

    Uses dense vector embeddings and location proximity checks to detect potential duplicates.
    Flags candidates without auto-merging (preserves human decision boundary).
    """

    def __init__(self, db: AsyncSession):
        self.db = db

    async def detect_duplicates(
        self, grievance_id: str, similarity_threshold: float = 0.65
    ) -> List[Dict[str, Any]]:
        """Compares target grievance against existing grievances to detect duplicates."""
        g_res = await self.db.execute(select(Grievance).where(Grievance.id == grievance_id))
        target_g = g_res.scalar_one_or_none()
        if not target_g:
            raise ValueError(f"Grievance '{grievance_id}' not found.")

        target_text = " ".join(
            filter(None, [target_g.title, target_g.description, target_g.original_text, target_g.translated_text])
        ).strip()

        if not target_text:
            return []

        target_vec = compute_vector(target_text)
        target_loc = target_g.confirmed_location or {}

        # Fetch all other active grievances
        others_res = await self.db.execute(
            select(Grievance).where(Grievance.id != grievance_id)
        )
        existing_list = others_res.scalars().all()

        duplicates = []

        for other in existing_list:
            other_text = " ".join(
                filter(None, [other.title, other.description, other.original_text, other.translated_text])
            ).strip()
            if not other_text:
                continue

            other_vec = compute_vector(other_text)
            sim_score = cosine_similarity(target_vec, other_vec)

            # Location proximity boost
            other_loc = other.confirmed_location or {}
            same_ward = (
                target_loc.get("district") == other_loc.get("district")
                and target_loc.get("ward") and target_loc.get("ward") == other_loc.get("ward")
            )
            if same_ward:
                sim_score = min(1.0, sim_score + 0.15)

            if sim_score >= similarity_threshold:
                match_reasons = {
                    "text_similarity_percent": round(sim_score * 100, 1),
                    "same_location_ward": same_ward,
                    "target_district": target_loc.get("district"),
                    "matched_district": other_loc.get("district"),
                }

                # Record or update persistent DuplicateDetection entity
                dup_res = await self.db.execute(
                    select(DuplicateDetection).where(
                        DuplicateDetection.grievance_id == grievance_id,
                        DuplicateDetection.matched_grievance_id == other.id,
                    )
                )
                dup_entity = dup_res.scalar_one_or_none()
                if not dup_entity:
                    dup_entity = DuplicateDetection(
                        grievance_id=grievance_id,
                        matched_grievance_id=other.id,
                        similarity_score=sim_score,
                        matching_reasons=match_reasons,
                        review_status="PENDING_REVIEW",
                    )
                    self.db.add(dup_entity)

                duplicates.append({
                    "matched_grievance_id": other.id,
                    "matched_grievance_number": other.grievance_number,
                    "matched_title": other.title,
                    "matched_status": other.status,
                    "matched_created_at": str(other.created_at),
                    "similarity_score": round(sim_score, 4),
                    "similarity_percentage": round(sim_score * 100, 1),
                    "matching_reasons": match_reasons,
                    "review_status": "PENDING_REVIEW",
                })

        await self.db.commit()

        duplicates.sort(key=lambda x: x["similarity_score"], reverse=True)
        return duplicates
