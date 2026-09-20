import asyncio
import time
import pytest
from app.database.session import AsyncSessionLocal, init_db_schema
from app.models.grievance_model import Grievance, IntakeMode, GrievanceStatus
from app.services.legal_service import LegalIntelligenceService
from app.services.knowledge_service import KnowledgeBaseService


@pytest.mark.asyncio
async def test_legal_intelligence_and_rag():
    await init_db_schema()

    async with AsyncSessionLocal() as session:
        ts = int(time.time())
        # 0. Create Citizen User
        from app.models.user_model import User
        cit_id = f"test_cit_{ts}"
        user = User(
            id=cit_id,
            full_name="Legal Test User",
            email=f"legal_test_{ts}@janmitra.gov.in",
            phone="9876543210",
            password_hash="hashed_pass",
            role="citizen",
            is_active=True,
        )
        session.add(user)

        # 1. Seed Government Knowledge Base
        kb = KnowledgeBaseService(session)
        count = await kb.seed_default_knowledge_base()
        print(f"Seeded {count} Government Knowledge Documents.")

        # 2. Vector search check
        search_results = await kb.search_relevant_chunks("water pipe leak main junction", top_k=3)
        assert len(search_results) > 0
        assert search_results[0]["document_title"] is not None and len(search_results[0]["document_title"]) > 0
        print("Vector search top match:", search_results[0]["section_title"])

        # 3. Create test grievance
        g_id = f"test_legal_g_{ts}"
        grievance = Grievance(
            id=g_id,
            grievance_number=f"JM-LEGAL-{ts}",
            citizen_id=cit_id,
            title="Severe Drinking Water Leakage Ward 5",
            description="Main pipe burst causing water loss and dirty water contamination in rural ward.",
            intake_mode=IntakeMode.DIRECT_TEXT,
            original_text="വാർഡ് 5 ൽ പ്രധാന കുടിവെള്ള പൈപ്പ് പൊട്ടി വെള്ളം നഷ്ടപ്പെടുന്നു.",
            status=GrievanceStatus.INTAKE_RECEIVED,
            category="Water Supply & Drainage",
        )
        session.add(grievance)
        await session.commit()

        # 4. Run Legal Intelligence Service
        legal_service = LegalIntelligenceService(session)
        res = await legal_service.analyze_legal_grounding(g_id)

        assert res["status"] == "COMPLETED"
        assert len(res["retrieved_sources"]) > 0
        assert len(res["legal_considerations"]) > 0
        assert "KWA" in str(res["required_documents"]) or "Proof" in str(res["required_documents"])
        assert "disclaimer" in res

        print("Legal Intelligence Test Passed Successfully! Retrieved", len(res["retrieved_sources"]), "grounded statutory sources.")


if __name__ == "__main__":
    asyncio.run(test_legal_intelligence_and_rag())
