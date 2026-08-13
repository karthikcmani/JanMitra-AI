import asyncio
import os
import sys
import time
from pathlib import Path
from app.database.session import AsyncSessionLocal

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from app.models.grievance_model import AttachmentType, GrievanceStatus
from app.schemas.grievance_schema import GrievanceDraftCreate
from app.schemas.user_schema import UserCreate, UserLogin
from app.services.auth_service import AuthService
from app.services.grievance_service import GrievanceService
from app.services.official_service import OfficialActionRequest, OfficialService


async def test_official_workflow():
    print("=" * 70)
    print("JanMitra AI — Official Login, OCR Processing & Department Routing Test")
    print("=" * 70)

    async with AsyncSessionLocal() as db:
        auth_service = AuthService(db)
        grievance_service = GrievanceService(db)
        official_service = OfficialService(db)

        # 1. Register & Authenticate Citizen
        ts = int(time.time())
        citizen_in = UserCreate(
            full_name="Karthik C Mani",
            email=f"citizen_{ts}@janmitra.in",
            phone="9876543210",
            password="Password123!",
            role="citizen",
        )
        citizen_db = await auth_service.register_user(citizen_in)
        print(f"\n1. Registered Citizen: {citizen_db.full_name} ({citizen_db.email})")

        # 2. Register & Authenticate Government Official
        official_in = UserCreate(
            full_name="Dr. John C. John (Executive Official)",
            email=f"official_{ts}@gov.in",
            phone="9123456789",
            password="OfficialPass123!",
            role="official",
        )
        official_db = await auth_service.register_user(official_in)
        print(f"2. Registered Official: {official_db.full_name} ({official_db.email})")

        official_token = await auth_service.authenticate_user(
            UserLogin(email=official_in.email, password=official_in.password)
        )
        print(f"   Issued Official JWT Access Token: {official_token.access_token[:25]}...")

        # 3. Citizen Submits Grievance Draft with Malayalam Petition Description
        draft_in = GrievanceDraftCreate(
            title="വാർഡ് 5 കുടിവെള്ള വിതരണം തടസ്സപ്പെട്ടു",
            description="ഞങ്ങളുടെ വാർഡിൽ പ്രധാന കുടിവെള്ള പൈപ്പ് പൊട്ടി വെള്ളം തടസ്സപ്പെട്ടിരിക്കുകയാണ്. ഉടൻ നടപടി വേണം.",
            priority="high",
            original_language="ml",
            original_text="വാർഡ് 5 ൽ കുടിവെള്ള വിതരണം തടസ്സപ്പെട്ടു. KWA പൈപ്പ് ലൈൻ ഉടൻ ശരിയാക്കണം.",
        )
        grievance = await grievance_service.create_draft(
            citizen_id=citizen_db.id, draft_in=draft_in
        )
        print(f"\n3. Created Citizen Grievance: {grievance.grievance_number} (ID: {grievance.id})")

        # 4. Official Dashboard: Fetch Pending Grievances
        pending_list = await official_service.get_all_official_grievances()
        print(f"\n4. Official Dashboard Fetched {len(pending_list)} Grievances.")

        # 5. Official Triggers Document Processing & Department Routing
        print("\n5. Triggering AI Document Processing & Automated Department Routing...")
        processed_detail = await official_service.process_document_and_route(
            grievance_id=grievance.id, official_id=official_db.id
        )

        print("\n--- AUTOMATED AI ROUTING RESULT ---")
        print(f"Predicted Department : {processed_detail.predicted_department}")
        print(f"Category             : {processed_detail.category}")
        print(f"Updated Status       : {processed_detail.status}")
        if processed_detail.legal_grounding_references:
            print(f"Statutory Act        : {processed_detail.legal_grounding_references.get('statutory_act')}")
            print(f"Matched Keywords     : {processed_detail.legal_grounding_references.get('matched_keywords')}")
            print(f"Confidence Score     : {processed_detail.legal_grounding_references.get('confidence_score')}")
        print(f"AI Grounding Summary : {processed_detail.ai_explanation}")

        # 6. Official Performs Action: Accept Route & Forward to KWA
        print("\n6. Official Submitting Administrative Action: Approve & Route to KWA...")
        action_in = OfficialActionRequest(
            department_name="Kerala Water Authority (KWA)",
            new_status=GrievanceStatus.FORWARDED,
            remarks="Verified Malayalam petition context. Approved and forwarded to KWA Executive Engineer for immediate repair.",
        )
        final_detail = await official_service.update_official_action(
            grievance_id=grievance.id, official_id=official_db.id, action_in=action_in
        )

        print("\n--- FINAL OFFICIAL ACTION RESULT ---")
        print(f"Assigned Department  : {final_detail.assigned_department}")
        print(f"Final Status         : {final_detail.status}")
        print(f"Latest Audit Log     : {final_detail.audit_logs[-1]['remarks'] if final_detail.audit_logs else 'N/A'}")
        print("=" * 70)
        print("OFFICIAL WORKFLOW VERIFICATION SUCCESSFUL!")
        print("=" * 70)


if __name__ == "__main__":
    asyncio.run(test_official_workflow())
