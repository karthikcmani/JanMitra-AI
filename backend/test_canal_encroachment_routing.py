import asyncio
import os
import sys
import time
from pathlib import Path
import pytest

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from app.database.session import AsyncSessionLocal, init_db_schema
from app.models.grievance_model import AttachmentType, GrievanceStatus, IntakeMode
from app.schemas.grievance_schema import GrievanceDraftCreate
from app.schemas.user_schema import UserCreate, UserLogin
from app.services.auth_service import AuthService
from app.services.grievance_service import GrievanceService
from app.services.official_service import OfficialService
from app.services.jurisdiction_service import JurisdictionIntelligenceService
from app.services.legal_service import LegalIntelligenceService
from app.services.ai_intelligence_service import AIIntelligenceService
from app.services.sequential_routing_engine import SequentialRoutingEngine


CANAL_ENCROACHMENT_PETITION = """
തീയതി : 04/10/2026
സ്ഥലം : വാഴപ്പള്ളി

സ്വീകർത്താവ്,
തഹസിൽദാർ ,
താലൂക്ക് ഓഫീസ്,
ചങ്ങനാശ്ശേരി,
കോട്ടയം ജില്ല.

അപേക്ഷകൻ,
വിജയൻ നായർ,
കിഴക്കേടത്ത് വീട്,
വാഴപ്പള്ളി പി.ഒ,
കോട്ടയം - 686503.
Ph: 9947123456

വിഷയം : സർക്കാർ പുറമ്പോക്ക് തോട് കയ്യേറ്റം ചെയ്ത് സ്വാഭാവിക നീരൊഴുക്ക് തടസ്സപ്പെടുത്തിയത് സംബന്ധിച്ച്.

സർ,
ഞങ്ങളുടെ വാഴപ്പള്ളി വില്ലേജിൽപ്പെട്ട റീ-സർവെ നമ്പർ 142/3-ന് സമീപമുള്ള സർക്കാർ പുറമ്പോക്ക് തോട് സമീപവാസിയായ ഒരാൾ അനധികൃതമായി മണ്ണ് നികത്തുകയും വേലി കെട്ടി കയ്യേറുകയും ചെയ്തിരിക്കുന്നതായി അറിയിക്കുന്നു.

ഇതിനാൽ കഴിഞ്ഞ മഴക്കാലത്ത് തോട്ടിലെ സ്വാഭാവിക നീരൊഴുക്ക് തടസ്സപ്പെട്ടത് കാരണം, സമീപത്തെ അഞ്ചിലധികം വീടുകളിൽ വെള്ളം കയറുകയും, കൃഷിയിടങ്ങൾക്ക് നാശനഷ്ടം ഉണ്ടാകുകയും ചെയ്തു. നിലവിൽ പോലും മഴ പെയ്യുമ്പോൾ വെള്ളം കെട്ടിനിൽക്കുന്ന അവസ്ഥയാണ്.

ഈ വിഷയത്തിൽ റവന്യൂ ഉദ്യോഗസ്ഥർ സ്ഥലം നേരിട്ട് സന്ദർശിച്ച് അളന്നു തിട്ടപ്പെടുത്തി, തോട്ടിലെ കയ്യേറ്റം ഒഴിപ്പിച്ച് സ്വാഭാവിക നീരൊഴുക്ക് പുനഃസ്ഥാപിക്കുന്നതിന് വേണ്ട അടിയന്തര നടപടി സ്വീകരിക്കണമെന്ന് വിനീതമായി അപേക്ഷിക്കുന്നു.

വിശ്വസ്തതയോടെ,
(ഒപ്പ്)
വിജയൻ നായർ
"""


@pytest.mark.asyncio
async def test_sequential_routing_engine_precision():
    print("\n--- 1. Testing Sequential Contextual Routing Engine Units ---")

    # Case A: Poramboke Canal Encroachment
    dec_canal = SequentialRoutingEngine.evaluate(
        CANAL_ENCROACHMENT_PETITION,
        location={"district": "Kottayam", "panchayat": "Vazhappally", "ward": "4"},
    )
    print(f"Canal Petition -> {dec_canal.department_name} ({dec_canal.category})")
    assert dec_canal.department_name == "Revenue & General Administration"
    assert "Kerala Land Conservancy Act" in dec_canal.statutory_act
    assert "Tahsildar" in dec_canal.recommended_authority
    assert dec_canal.confidence_score >= 0.90

    # Case B: Drinking Water Pipe Burst (Must be KWA)
    kwa_text = "ഞങ്ങളുടെ വാർഡിൽ കുടിവെള്ള പൈപ്പ് പൊട്ടി വെള്ളം പാഴാകുന്നു. അടിയന്തരമായി വാട്ടർ അതോറിറ്റി പരിഹരിക്കണം."
    dec_kwa = SequentialRoutingEngine.evaluate(kwa_text)
    print(f"Pipe Burst -> {dec_kwa.department_name}")
    assert dec_kwa.department_name == "Kerala Water Authority (KWA)"

    # Case C: PWD Road Pothole
    pwd_text = "പൊതുമരാമത്ത് റോഡിലെ വലിയ കുഴികൾ കാരണം വാഹനങ്ങൾ അപകടത്തിൽപ്പെടുന്നു. റോഡ് ടാർ ചെയ്യണം."
    dec_pwd = SequentialRoutingEngine.evaluate(pwd_text)
    print(f"Road Pothole -> {dec_pwd.department_name}")
    assert dec_pwd.department_name == "Public Works Department (PWD)"

    # Case D: LSGD Panchayat Waste
    lsgd_text = "പഞ്ചായത്ത് വാർഡിൽ മാലിന്യ നിക്ഷേപം കാരണം കൊതുക് ശല്യവും ദുർഗന്ധവും ഉണ്ടാകുന്നു. മാലിന്യം നീക്കണം."
    dec_lsgd = SequentialRoutingEngine.evaluate(lsgd_text)
    print(f"Panchayat Waste -> {dec_lsgd.department_name}")
    assert "Local Self Government" in dec_lsgd.department_name

    print("SequentialRoutingEngine unit evaluations passed flawlessly!")


@pytest.mark.asyncio
async def test_canal_grievance_end_to_end_pipeline():
    print("\n--- 2. End-to-End Pipeline: Canal Grievance Intake, Routing & Official Queue ---")
    await init_db_schema()

    async with AsyncSessionLocal() as db:
        from app.services.knowledge_service import KnowledgeBaseService
        kb_service = KnowledgeBaseService(db)
        await kb_service.seed_default_knowledge_base()

        auth_service = AuthService(db)
        grievance_service = GrievanceService(db)
        official_service = OfficialService(db)
        jurisdiction_service = JurisdictionIntelligenceService(db)
        legal_service = LegalIntelligenceService(db)
        ai_intel_service = AIIntelligenceService(db)

        # 1. Register Citizen
        ts = int(time.time())
        citizen_in = UserCreate(
            full_name="Vijayan Nair (Changanassery)",
            email=f"vijayan_{ts}@janmitra.in",
            phone="9947123456",
            password="Password123!",
            role="citizen",
        )
        citizen_db = await auth_service.register_user(citizen_in)

        # 2. Register Revenue Official
        revenue_official_in = UserCreate(
            full_name="Tahsildar (Changanassery Taluk)",
            email=f"tahsildar_{ts}@kerala.gov.in",
            phone="9847112233",
            password="OfficialPass123!",
            role="official",
        )
        revenue_off_db = await auth_service.register_user(revenue_official_in)

        # 3. Create Draft with Canal Petition
        draft_in = GrievanceDraftCreate(
            title="സർക്കാർ പുറമ്പോക്ക് തോട് കയ്യേറ്റം ചെയ്ത് സ്വാഭാവിക നീരൊഴുക്ക് തടസ്സപ്പെടുത്തി",
            description="റീ-സർവെ നമ്പർ 142/3-ന് സമീപമുള്ള സർക്കാർ പുറമ്പോക്ക് തോട് കയ്യേറ്റം",
            intake_mode="ocr_handwritten",
            original_language="ml",
            confirmed_location={"district": "Kottayam", "panchayat": "Vazhappally", "ward": "4"},
        )
        created_g = await grievance_service.create_draft(citizen_id=citizen_db.id, draft_in=draft_in)
        print(f"Created Grievance Draft: {created_g.grievance_number} ({created_g.id})")

        # 4. Citizen Verifies & Submits Petition Text
        submitted_g = await grievance_service.verify_and_submit(
            citizen_id=citizen_db.id,
            grievance_id=created_g.id,
            verified_text=CANAL_ENCROACHMENT_PETITION,
        )

        # 5. Verify Jurisdiction Recommendation
        juris_rec = await jurisdiction_service.recommend_jurisdiction(created_g.id)
        print(f"Jurisdiction Recommendation Department: {juris_rec['department_name']}")
        print(f"Recommended Authority: {juris_rec['recommended_authority']}")
        assert juris_rec["department_name"] == "Revenue & General Administration"
        assert "Tahsildar" in juris_rec["recommended_authority"]
        assert "Kerala Water Authority" not in juris_rec["department_name"]

        # 6. Verify Official Queue Decision Support
        official_grievances = await official_service.get_all_official_grievances()
        matched = [g for g in official_grievances if g.id == created_g.id]
        assert len(matched) == 1
        g_detail = matched[0]

        print(f"Official Queue Assigned Department: {g_detail.assigned_department}")
        print(f"Official Queue Decision Support Dept: {g_detail.decision_support.suggested_department}")
        print(f"Statutory Relevance: {g_detail.decision_support.statutory_relevance}")

        assert g_detail.assigned_department == "Revenue & General Administration"
        assert g_detail.decision_support.suggested_department == "Revenue & General Administration"
        assert "Kerala Land Conservancy Act" in g_detail.decision_support.statutory_relevance

        print("\nCanal Encroachment Grievance is 100% properly routed to Revenue Department!")


if __name__ == "__main__":
    asyncio.run(test_sequential_routing_engine_precision())
    asyncio.run(test_canal_grievance_end_to_end_pipeline())
