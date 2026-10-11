import asyncio
import sys
import pytest

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

from app.database.session import AsyncSessionLocal, init_db_schema
from app.models.grievance_model import GrievanceStatus
from app.models.user_model import User
from app.schemas.grievance_schema import GrievanceDraftCreate, GrievanceVerificationRequest
from app.schemas.user_schema import UserLogin
from app.services.auth_service import AuthService
from app.services.grievance_service import GrievanceService
from app.services.official_service import OfficialActionRequest, OfficialService
from sqlalchemy import select


@pytest.mark.asyncio
async def test_multi_issue_decomposition_e2e():
    print("\n" + "=" * 75)
    print("JANMITRA AI — End-to-End Multi-Issue Sub-Grievance Decomposition & Routing Test")
    print("=" * 75)

    await init_db_schema()

    async with AsyncSessionLocal() as db:
        auth_service = AuthService(db)
        grievance_service = GrievanceService(db)
        official_service = OfficialService(db)

        # 1. Authenticate Citizen
        cit_token = await auth_service.authenticate_user(
            UserLogin(email="citizen@janmitra.gov.in", password="Citizen@JanMitra2026")
        )
        citizen_id = cit_token.user.id
        print(f"1. Authenticated Citizen: {cit_token.user.full_name} ({citizen_id})")

        # 2. Citizen creates draft petition containing multiple distinct issues across Revenue, KWA, and PWD
        multi_issue_petition = (
            "ബഹുമാനപ്പെട്ട തഹസിൽദാർ മുൻപാകെ ബോധിപ്പിക്കുന്ന പരാതി. "
            "ഞങ്ങളുടെ പ്രദേശത്തെ പൊതു തോട് പുറമ്പോക്ക് സ്വകാര്യ വ്യക്തി അനധികൃതമായി കയ്യേറി മതിൽ കെട്ടി അടച്ചിരിക്കുന്നു. "
            "കൂടാതെ പ്രധാന റോഡിലെ കുടിവെള്ള പൈപ്പ് പൊട്ടി ശുദ്ധജലം റോഡിലേക്ക് ഒഴുകി പാഴാകുന്നു. "
            "ഇതുമൂലം റോഡിൽ വലിയ കുഴികൾ രൂപപ്പെട്ട് ഗതാഗതം തടസ്സപ്പെട്ടിരിക്കുകയാണ്."
        )

        draft = await grievance_service.create_draft(
            citizen_id=citizen_id,
            draft_in=GrievanceDraftCreate(
                title="പൊതു തോട് കയ്യേറ്റവും പൈപ്പ് പൊട്ടലും റോഡ് തകർച്ചയും",
                description=multi_issue_petition,
                original_text=multi_issue_petition,
                intake_mode="direct_text",
                original_language="ml",
            ),
        )
        print(f"2. Created Parent Grievance Draft: {draft.grievance_number} ({draft.id})")

        # 3. Citizen verifies and confirms the petition text (triggers AI intelligence & automated sub-ticket decomposition)
        confirmed = await grievance_service.verify_and_submit(
            citizen_id=citizen_id,
            grievance_id=draft.id,
            verified_text=multi_issue_petition,
        )
        print(f"3. Verified & Submitted. Parent Status: {confirmed.status}")
        print(f"   Detected Issue Count: {len(confirmed.issues)}")
        for iss in confirmed.issues:
            print(f"    - Issue {iss.issue_number}: [{iss.category}] {iss.title}")

        # 4. Fetch citizen grievances and verify Parent has Sub-Grievances
        citizen_grievances = await grievance_service.get_citizen_grievances(citizen_id=citizen_id)
        parent_match = next((g for g in citizen_grievances if g.id == draft.id), None)
        assert parent_match is not None, "Parent grievance must appear in citizen's list"

        print(f"\n4. Citizen Grievance View:")
        print(f"   Parent: {parent_match.grievance_number} (Status: {parent_match.status})")
        print(f"   Sub-Tickets Generated: {len(parent_match.sub_grievances)}")
        assert len(parent_match.sub_grievances) >= 2, "Expected at least 2 decomposed sub-tickets"

        for sub in parent_match.sub_grievances:
            print(f"    -> Sub-Ticket: {sub.grievance_number} | Dept: {sub.department_id} | Category: {sub.category} | Status: {sub.status}")

        # Sub-ticket A must be Revenue & Land Conservancy (Thodu encroachment)
        sub_revenue = next((s for s in parent_match.sub_grievances if "Revenue" in (s.department_id or "")), None)
        assert sub_revenue is not None, "Revenue department sub-ticket must be generated for canal encroachment"
        print(f"   [PASS] Found Revenue sub-ticket: {sub_revenue.grievance_number} assigned to {sub_revenue.department_id}")

        # Sub-ticket B must be Water Authority (Drinking water pipe leak)
        sub_kwa = next((s for s in parent_match.sub_grievances if "Water" in (s.department_id or "") or "KWA" in (s.department_id or "")), None)
        assert sub_kwa is not None, "KWA sub-ticket must be generated for drinking water pipe leak"
        print(f"   [PASS] Found KWA sub-ticket: {sub_kwa.grievance_number} assigned to {sub_kwa.department_id}")

        # 5. Official Portals Verification:
        # A. Revenue Official logs in and searches their queue
        rev_token = await auth_service.authenticate_user(
            UserLogin(email="official.revenue@janmitra.gov.in", password="Official@Revenue2026")
        )
        rev_queue = await official_service.search_official_grievances(
            department_id="Revenue & General Administration"
        )
        rev_numbers = [g.grievance_number for g in rev_queue]
        print(f"\n5. Revenue Official Queue ({len(rev_queue)} items):")
        assert sub_revenue.grievance_number in rev_numbers, f"{sub_revenue.grievance_number} must appear in Revenue queue"
        assert sub_kwa.grievance_number not in rev_numbers, f"KWA sub-ticket {sub_kwa.grievance_number} must NOT appear in Revenue queue"
        print(f"   [PASS] Revenue official sees only {sub_revenue.grievance_number}")

        # B. KWA Official logs in and searches their queue
        kwa_token = await auth_service.authenticate_user(
            UserLogin(email="official.kwa@janmitra.gov.in", password="Official@KWA2026")
        )
        kwa_queue = await official_service.search_official_grievances(
            department_id="Kerala Water Authority (KWA)"
        )
        kwa_numbers = [g.grievance_number for g in kwa_queue]
        print(f"\n6. KWA Official Queue ({len(kwa_queue)} items):")
        assert sub_kwa.grievance_number in kwa_numbers, f"{sub_kwa.grievance_number} must appear in KWA queue"
        assert sub_revenue.grievance_number not in kwa_numbers, f"Revenue sub-ticket {sub_revenue.grievance_number} must NOT appear in KWA queue"
        print(f"   [PASS] KWA official sees only {sub_kwa.grievance_number}")

        # 7. Official Administrative Action: Revenue Official conducts inspection and updates status
        print(f"\n7. Revenue Official executing administrative action on {sub_revenue.grievance_number}...")
        updated_sub = await official_service.update_official_action(
            grievance_id=sub_revenue.id,
            official_id=rev_token.user.id,
            action_in=OfficialActionRequest(
                department_name="Revenue & General Administration",
                new_status=GrievanceStatus.UNDER_PROCESSING,
                remarks="Site inspection conducted by Village Officer. Encroachment of canal poramboke verified under Section 11 of Kerala Land Conservancy Act. Form C notice initiated.",
            ),
        )
        assert updated_sub.status == GrievanceStatus.UNDER_PROCESSING
        print(f"   [PASS] Sub-ticket {sub_revenue.grievance_number} status updated to {updated_sub.status}")

        # 8. Citizen re-checks grievance status:
        refreshed_citizen_list = await grievance_service.get_citizen_grievances(citizen_id=citizen_id)
        refreshed_parent = next((g for g in refreshed_citizen_list if g.id == draft.id), None)
        refreshed_revenue_sub = next((s for s in refreshed_parent.sub_grievances if s.id == sub_revenue.id), None)
        assert refreshed_revenue_sub.status == GrievanceStatus.UNDER_PROCESSING
        print(f"\n8. Citizen Real-time Tracking Verified:")
        print(f"   Parent {refreshed_parent.grievance_number} -> Sub {refreshed_revenue_sub.grievance_number} is now: {refreshed_revenue_sub.status}")

    print("\n" + "=" * 75)
    print("ALL MULTI-ISSUE SUB-GRIEVANCE DECOMPOSITION & OFFICIAL ROUTING TESTS PASSED 100%!")
    print("=" * 75)


if __name__ == "__main__":
    asyncio.run(test_multi_issue_decomposition_e2e())
