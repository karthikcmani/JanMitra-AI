import asyncio
import time
import pytest
from httpx import ASGITransport, AsyncClient

from app.database.session import AsyncSessionLocal, init_db_schema
from app.main import app
from app.models.user_model import User


@pytest.mark.asyncio
async def test_e2e_full_janmitra_lifecycle():
    await init_db_schema()

    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        ts = int(time.time())

        # 1. Register Citizen, Admin, and Official
        cit_email = f"e2e_citizen_{ts}@janmitra.gov.in"
        admin_email = f"e2e_admin_{ts}@janmitra.gov.in"
        off_email = f"e2e_kwa_official_{ts}@janmitra.gov.in"
        password = "Password123!"

        await client.post("/api/v1/auth/register", json={"full_name": "Deepa Menon", "email": cit_email, "phone": "9876543210", "password": password, "role": "citizen"})
        await client.post("/api/v1/auth/register", json={"full_name": "State Admin Director", "email": admin_email, "phone": "9999999999", "password": password, "role": "admin"})
        await client.post("/api/v1/auth/register", json={"full_name": "KWA Executive Engineer", "email": off_email, "phone": "8888888888", "password": password, "role": "official"})

        cit_login = await client.post("/api/v1/auth/login", json={"email": cit_email, "password": password})
        admin_login = await client.post("/api/v1/auth/login", json={"email": admin_email, "password": password})
        off_login = await client.post("/api/v1/auth/login", json={"email": off_email, "password": password})

        cit_headers = {"Authorization": f"Bearer {cit_login.json()['access_token']}"}
        admin_headers = {"Authorization": f"Bearer {admin_login.json()['access_token']}"}
        off_headers = {"Authorization": f"Bearer {off_login.json()['access_token']}"}
        off_id = off_login.json()["user"]["id"]

        print("\n--- 1. Auth & Token Generation Passed ---")

        # 2. Citizen creates a grievance draft
        create_res = await client.post(
            "/api/v1/grievances/intake/draft",
            json={
                "title": "Severe Water Pipe Leakage & Contamination Ward 5",
                "description": "Main drinking water pipe burst in Ward 5 causing severe water shortage and dirty water entering residential tanks.",
            },
            headers=cit_headers,
        )
        assert create_res.status_code == 201
        g_id = create_res.json()["id"]
        print(f"--- 2. Grievance Draft Initialized: {create_res.json()['grievance_number']} ---")

        # 3. Citizen verifies petition text
        verified_text = "ഞങ്ങളുടെ ഗ്രാമപഞ്ചായത്തിൽ വാർഡ് 5 ൽ പ്രധാന കുടിവെള്ള പൈപ്പ് പൊട്ടി 3 ദിവസമായി വെള്ളം പാഴാകുന്നു. കുടിവെള്ള വിതരണം തടസ്സപ്പെട്ടു."
        verify_res = await client.post(
            f"/api/v1/grievances/{g_id}/verify",
            json={"verified_text": verified_text},
            headers=cit_headers,
        )
        assert verify_res.status_code == 200
        print("--- 3. Citizen Text Verified & Pipeline Triggered ---")

        # 4. Check Legal Intelligence endpoint
        legal_res = await client.post(f"/api/v1/legal/grievance/{g_id}/analyze", headers=cit_headers)
        assert legal_res.status_code == 200
        legal_data = legal_res.json()
        assert len(legal_data["retrieved_sources"]) > 0
        print(f"--- 4. RAG Legal Intelligence Verified: {len(legal_data['retrieved_sources'])} statutory sources retrieved ---")

        # 5. Check Jurisdiction Recommendation endpoint
        juris_res = await client.post(f"/api/v1/jurisdiction/grievance/{g_id}/recommend", headers=cit_headers)
        assert juris_res.status_code == 200
        juris_data = juris_res.json()
        assert "Kerala Water Authority" in juris_data["department_name"] or "Panchayat" in juris_data["department_name"]
        print(f"--- 5. Jurisdiction Recommendation Verified: {juris_data['recommended_authority']} ---")

        # 6. Check Duplicate Detection endpoint
        dup_res = await client.get(f"/api/v1/duplicates/grievance/{g_id}", headers=cit_headers)
        assert dup_res.status_code == 200
        print("--- 6. Duplicate Detection Checked ---")

        # 7. Admin assigns grievance to official
        assign_res = await client.post(
            f"/api/v1/official/admin/grievances/{g_id}/assign",
            json={
                "department_name": "Kerala Water Authority (KWA)",
                "assigned_official_id": off_id,
                "new_status": "forwarded",
                "remarks": "Assigned to KWA Executive Engineer for site repair.",
            },
            headers=admin_headers,
        )
        assert assign_res.status_code == 200
        print("--- 7. Admin Assignment Verified ---")

        # 8. Official records resolution
        resolve_res = await client.post(
            f"/api/v1/official/grievances/{g_id}/action",
            json={
                "new_status": "resolved",
                "remarks": "Main pipeline burst repaired and normal drinking water supply restored.",
            },
            headers=off_headers,
        )
        assert resolve_res.status_code == 200
        assert resolve_res.json()["status"] == "resolved"
        print("--- 8. Official Resolution Recorded ---")

        # 9. Citizen Notifications endpoint check
        notif_res = await client.get("/api/v1/notifications/my", headers=cit_headers)
        assert notif_res.status_code == 200
        assert len(notif_res.json()) >= 1
        print("--- 9. Citizen In-App Notifications Verified ---")

        print("\n=======================================================")
        print("JANMITRA AI FULL END-TO-END LIFECYCLE TEST PASSED 100%!")
        print("=======================================================")


if __name__ == "__main__":
    asyncio.run(test_e2e_full_janmitra_lifecycle())
