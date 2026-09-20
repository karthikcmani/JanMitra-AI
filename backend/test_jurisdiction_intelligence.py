import asyncio
import time
import pytest
from app.database.session import AsyncSessionLocal, init_db_schema
from app.models.grievance_model import Grievance, IntakeMode, GrievanceStatus
from app.models.user_model import User
from app.services.jurisdiction_service import JurisdictionIntelligenceService


@pytest.mark.asyncio
async def test_jurisdiction_intelligence():
    await init_db_schema()

    async with AsyncSessionLocal() as session:
        ts = int(time.time())
        cit_id = f"cit_juris_{ts}"
        off_id = f"off_juris_{ts}"

        session.add(User(id=cit_id, full_name="Citizen One", email=f"cit_j_{ts}@gov.in", password_hash="p", role="citizen"))
        session.add(User(id=off_id, full_name="Admin Officer", email=f"off_j_{ts}@gov.in", password_hash="p", role="admin"))
        await session.commit()

        # Create grievance with location
        g_id = f"g_juris_{ts}"
        grievance = Grievance(
            id=g_id,
            grievance_number=f"JM-JURIS-{ts}",
            citizen_id=cit_id,
            title="Dangerous Leaning Electric Pole Ward 12",
            description="High voltage wire hanging low over public street junction.",
            intake_mode=IntakeMode.DIRECT_TEXT,
            original_text="വൈദ്യുതി പോസ്റ്റ് മറിഞ്ഞുവീഴാറായ അവസ്ഥയിലാണ്.",
            status=GrievanceStatus.INTAKE_RECEIVED,
            category="Power & Electricity",
            confirmed_location={"district": "Ernakulam", "panchayat": "Kizhakkambalam", "ward": "12"},
        )
        session.add(grievance)
        await session.commit()

        # Run Jurisdiction Recommendation Service
        service = JurisdictionIntelligenceService(session)
        rec = await service.recommend_jurisdiction(g_id)

        assert "Kerala State Electricity Board" in rec["department_name"]
        assert "SECTION_OFFICE" in rec["jurisdiction_level"] or "Section Office" in rec["recommended_authority"]
        assert rec["confidence_score"] >= 0.85
        print("Jurisdiction Recommendation Passed:", rec["recommended_authority"])

        # Override Recommendation
        override_res = await service.override_recommendation(
            grievance_id=g_id,
            official_id=off_id,
            new_department="Public Works Department (PWD)",
            new_authority="PWD Special Electrical Sub-Division",
            remarks="Re-routed to PWD Electrical division for joint inspection.",
        )
        assert override_res["status"] == "success"
        assert override_res["department_name"] == "Public Works Department (PWD)"
        print("Jurisdiction Override Passed Successfully!")


if __name__ == "__main__":
    asyncio.run(test_jurisdiction_intelligence())
