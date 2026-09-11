import asyncio
import time
import pytest
from app.database.session import AsyncSessionLocal, init_db_schema
from app.models.grievance_model import Grievance, IntakeMode, GrievanceStatus
from app.models.user_model import User
from app.services.duplicate_service import DuplicateDetectionService


@pytest.mark.asyncio
async def test_duplicate_grievance_detection():
    await init_db_schema()

    async with AsyncSessionLocal() as session:
        ts = int(time.time())
        cit_id = f"cit_dup_{ts}"
        session.add(User(id=cit_id, full_name="Citizen Tester", email=f"dup_cit_{ts}@gov.in", password_hash="pass", role="citizen"))
        await session.commit()

        # 1. Create Existing Grievance
        g1_id = f"g1_dup_{ts}"
        g1 = Grievance(
            id=g1_id,
            grievance_number=f"JM-EXISTING-{ts}",
            citizen_id=cit_id,
            title="Main Drinking Water Pipe Burst Near Govt School",
            description="Continuous water leakage near Ward 5 Government High School junction.",
            intake_mode=IntakeMode.DIRECT_TEXT,
            original_text="ഹൈസ്കൂൾ കവലയിൽ കുടിവെള്ള പൈപ്പ് പൊട്ടി വെള്ളം നഷ്ടപ്പെടുന്നു.",
            status=GrievanceStatus.INTAKE_RECEIVED,
            confirmed_location={"district": "Ernakulam", "ward": "5"},
        )
        session.add(g1)
        await session.commit()

        # 2. Create Target Duplicate Grievance
        g2_id = f"g2_dup_{ts}"
        g2 = Grievance(
            id=g2_id,
            grievance_number=f"JM-NEW-{ts}",
            citizen_id=cit_id,
            title="Pipe Leakage Ward 5 High School Junction",
            description="Water pipeline burst causing road flooding near high school ward 5.",
            intake_mode=IntakeMode.DIRECT_TEXT,
            original_text="വാർഡ് 5 ഹൈസ്കൂളിന് സമീപം പൈപ്പ് ചോർച്ച.",
            status=GrievanceStatus.INTAKE_RECEIVED,
            confirmed_location={"district": "Ernakulam", "ward": "5"},
        )
        session.add(g2)
        await session.commit()

        # 3. Detect duplicates
        service = DuplicateDetectionService(session)
        duplicates = await service.detect_duplicates(g2_id, similarity_threshold=0.45)

        assert len(duplicates) >= 1
        matched_ids = [d["matched_grievance_id"] for d in duplicates]
        assert g1_id in matched_ids
        target_match = next(d for d in duplicates if d["matched_grievance_id"] == g1_id)
        assert target_match["similarity_score"] >= 0.45
        assert target_match["matching_reasons"]["same_location_ward"] is True
        print(f"Duplicate Detection Test Passed! Matched {target_match['matched_grievance_number']} with similarity score {target_match['similarity_percentage']}%.")


if __name__ == "__main__":
    asyncio.run(test_duplicate_grievance_detection())
