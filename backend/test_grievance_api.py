import asyncio
import time
from httpx import ASGITransport, AsyncClient
import pytest
from sqlalchemy import select
from app.database.session import AsyncSessionLocal
from app.main import app
from app.models.grievance_model import Grievance, GrievanceAuditLog


@pytest.mark.asyncio
async def test_grievance_api_flow():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        timestamp_a = int(time.time())
        email_a = f"citizen_a_{timestamp_a}@gov.in"
        password_a = "Password123!"

        timestamp_b = timestamp_a + 1
        email_b = f"citizen_b_{timestamp_b}@gov.in"
        password_b = "Password123!"

        print("\n--- 1. Testing Unauthenticated Request Rejection (401) ---")
        unauth_res = await client.get("/api/v1/grievances/my")
        assert unauth_res.status_code == 401, (
            f"Expected 401 for unauth request, got {unauth_res.status_code}"
        )
        print("Unauthenticated Request rejected with 401 Unauthorized.")

        print("\n--- 2. Registering and Logging in Citizen A & Citizen B ---")
        reg_a = await client.post(
            "/api/v1/auth/register",
            json={
                "full_name": "Citizen A",
                "email": email_a,
                "phone": "9876543210",
                "password": password_a,
                "role": "citizen",
            },
        )
        assert reg_a.status_code == 201
        user_a_id = reg_a.json()["user"]["id"]

        login_a = await client.post(
            "/api/v1/auth/login",
            json={"email": email_a, "password": password_a},
        )
        assert login_a.status_code == 200
        token_a = login_a.json()["access_token"]
        headers_a = {"Authorization": f"Bearer {token_a}"}

        reg_b = await client.post(
            "/api/v1/auth/register",
            json={
                "full_name": "Citizen B",
                "email": email_b,
                "phone": "9876543211",
                "password": password_b,
                "role": "citizen",
            },
        )
        assert reg_b.status_code == 201

        login_b = await client.post(
            "/api/v1/auth/login",
            json={"email": email_b, "password": password_b},
        )
        assert login_b.status_code == 200
        token_b = login_b.json()["access_token"]
        headers_b = {"Authorization": f"Bearer {token_b}"}

        print("\n--- 3. Testing POST /api/v1/grievances/intake/draft (Citizen A) ---")
        draft_payload = {
            "title": "Broken Streetlight in Ward 12",
            "description": "Streetlight near house #45 has been non-functional for 2 weeks.",
            "intake_mode": "direct_text",
            "original_language": "en",
            "original_text": "Broken Streetlight in Ward 12",
            "translated_text": "Broken Streetlight in Ward 12",
            "priority": "medium",
            "confirmed_location": {"district": "Thiruvananthapuram", "ward": "12"},
        }
        res_draft = await client.post(
            "/api/v1/grievances/intake/draft",
            json=draft_payload,
            headers=headers_a,
        )
        assert res_draft.status_code == 201, (
            f"Draft creation failed ({res_draft.status_code}): {res_draft.text}"
        )
        g_data_a = res_draft.json()
        grievance_a_id = g_data_a["id"]
        grievance_no_a = g_data_a["grievance_number"]

        assert g_data_a["citizen_id"] == user_a_id
        assert g_data_a["status"] == "draft"
        assert grievance_no_a.startswith("JM-2026-")
        print(f"Created Draft Grievance A: {grievance_no_a} (id: {grievance_a_id})")

        print("\n--- 4. Creating Second Draft & Verifying Unique Server Grievance Numbers ---")
        res_draft_a2 = await client.post(
            "/api/v1/grievances/intake/draft",
            json={"title": "Second Grievance by Citizen A"},
            headers=headers_a,
        )
        assert res_draft_a2.status_code == 201
        grievance_no_a2 = res_draft_a2.json()["grievance_number"]
        assert grievance_no_a != grievance_no_a2
        print(f"Unique Grievance Numbers Verified: {grievance_no_a} vs {grievance_no_a2}")

        print("\n--- 5. Verifying Grievance Record & Creation Audit Log in PostgreSQL ---")
        async with AsyncSessionLocal() as db_session:
            db_res = await db_session.execute(
                select(Grievance).where(Grievance.id == grievance_a_id)
            )
            db_grievance = db_res.scalar_one_or_none()
            assert db_grievance is not None
            assert db_grievance.citizen_id == user_a_id

            audit_res = await db_session.execute(
                select(GrievanceAuditLog).where(
                    GrievanceAuditLog.grievance_id == grievance_a_id
                )
            )
            audit_log = audit_res.scalar_one_or_none()
            assert audit_log is not None
            assert audit_log.action_type == "created"
            assert audit_log.actor_id == user_a_id
            assert audit_log.new_state == "draft"
            print("PostgreSQL record & Creation Audit Log confirmed in DB!")

        print("\n--- 6. Testing GET /api/v1/grievances/my (Citizen A) ---")
        res_my = await client.get("/api/v1/grievances/my", headers=headers_a)
        assert res_my.status_code == 200
        my_list = res_my.json()
        assert len(my_list) >= 2
        assert my_list[0]["created_at"] >= my_list[1]["created_at"]
        print(f"GET /my returned {len(my_list)} grievances ordered newest first.")

        print("\n--- 7. Testing GET /api/v1/grievances/{id} (Citizen A) ---")
        res_detail = await client.get(
            f"/api/v1/grievances/{grievance_a_id}", headers=headers_a
        )
        assert res_detail.status_code == 200
        assert res_detail.json()["id"] == grievance_a_id
        print("GET /{id} returned correct grievance detail for owner.")

        print("\n--- 8. Testing Unauthorized Access Rejection (Citizen B accessing Citizen A's Grievance) ---")
        res_unauth_access = await client.get(
            f"/api/v1/grievances/{grievance_a_id}", headers=headers_b
        )
        assert res_unauth_access.status_code == 404, (
            f"Expected 404 for unauthorized access, got {res_unauth_access.status_code}"
        )
        print("Unauthorized access by Citizen B cleanly rejected with 404 Not Found.")

        print("\nALL SPRINT 9 / PHASE 1B GRIEVANCE REST API TESTS PASSED 100%!")


if __name__ == "__main__":
    asyncio.run(test_grievance_api_flow())
