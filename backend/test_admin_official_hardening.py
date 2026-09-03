import asyncio
import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.core.security import create_access_token, get_password_hash
from app.database.session import AsyncSessionLocal, Base, engine
from app.main import app
from app.models.grievance_model import (
    ExtractionStatus,
    Grievance,
    GrievanceAttachment,
    GrievanceAuditLog,
    GrievanceStatus,
)
from app.models.user_model import User


@pytest.mark.asyncio
async def test_admin_and_official_hardened_workflow():
    from app.database.session import init_db_schema
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await init_db_schema()
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        import time
        ts = int(time.time())

        # 1. Register & Login Citizen, Admin, and Official users via API
        cit_email = f"cit_hardened_{ts}@janmitra.gov.in"
        admin_email = f"admin_hardened_{ts}@janmitra.gov.in"
        off_email = f"official_kwa_{ts}@janmitra.gov.in"
        pass_str = "Password123!"

        await client.post("/api/v1/auth/register", json={"full_name": "Citizen User", "email": cit_email, "phone": "9876543210", "password": pass_str, "role": "citizen"})
        await client.post("/api/v1/auth/register", json={"full_name": "State Admin Officer", "email": admin_email, "phone": "9999999999", "password": pass_str, "role": "admin"})
        await client.post("/api/v1/auth/register", json={"full_name": "KWA Executive Officer", "email": off_email, "phone": "8888888888", "password": pass_str, "role": "official"})

        cit_login = await client.post("/api/v1/auth/login", json={"email": cit_email, "password": pass_str})
        admin_login = await client.post("/api/v1/auth/login", json={"email": admin_email, "password": pass_str})
        off_login = await client.post("/api/v1/auth/login", json={"email": off_email, "password": pass_str})

        cit_headers = {"Authorization": f"Bearer {cit_login.json()['access_token']}"}
        admin_headers = {"Authorization": f"Bearer {admin_login.json()['access_token']}"}
        off_headers = {"Authorization": f"Bearer {off_login.json()['access_token']}"}

        off_id = off_login.json()["user"]["id"]

        # 2. Citizen creates a grievance
        create_res = await client.post(
            "/api/v1/grievances/intake/draft",
            json={"title": "Pipe Leakage Ward 5", "description": "Water leaking continuously near main junction"},
            headers=cit_headers,
        )
        assert create_res.status_code == 201
        grievance_id = create_res.json()["id"]

        # 3. Citizen verifies petition text
        verify_res = await client.post(
            f"/api/v1/grievances/{grievance_id}/verify",
            json={"verified_text": "ഞങ്ങളുടെ ഗ്രാമത്തിൽ കുടിവെള്ള പൈപ്പ് പൊട്ടി വെള്ളം പാഴാകുന്നു."},
            headers=cit_headers,
        )
        assert verify_res.status_code == 200
        assert verify_res.json()["status"] in ("intake_received", "under_analysis")

        # 4. Non-admin user (Official or Citizen) attempts Admin endpoint -> 403 Forbidden
        forbidden_res = await client.get("/api/v1/official/admin/officials", headers=off_headers)
        assert forbidden_res.status_code == 403

        # 5. Admin accesses Dashboard Summary & Roster
        dash_res = await client.get("/api/v1/official/dashboard/summary", headers=admin_headers)
        assert dash_res.status_code == 200
        summary_data = dash_res.json()
        assert summary_data["total_grievances"] >= 1

        officials_res = await client.get("/api/v1/official/admin/officials", headers=admin_headers)
        assert officials_res.status_code == 200
        assert len(officials_res.json()) >= 1

        # 6. Admin assigns grievance to Kerala Water Authority and Executive Officer
        assign_res = await client.post(
            f"/api/v1/official/admin/grievances/{grievance_id}/assign",
            json={
                "department_name": "Kerala Water Authority (KWA)",
                "assigned_official_id": off_id,
                "new_status": "forwarded",
                "remarks": "Assigned to KWA Executive Officer for site inspection.",
            },
            headers=admin_headers,
        )
        assert assign_res.status_code == 200
        g_data = assign_res.json()
        assert g_data["assigned_department"] == "Kerala Water Authority (KWA)"
        assert g_data["assigned_official_id"] == off_id
        assert g_data["status"] == "forwarded"

        # 7. Official reviews and submits official action (Request Clarification)
        clarify_action = await client.post(
            f"/api/v1/official/grievances/{grievance_id}/action",
            json={
                "new_status": "clarification_required",
                "question": "Please provide the exact street or landmark near Ward 5 junction.",
                "remarks": "Clarification needed for field team location.",
            },
            headers=off_headers,
        )
        assert clarify_action.status_code == 200
        assert clarify_action.json()["status"] == "clarification_required"

        # 8. Citizen responds to clarification
        citizen_clarify_res = await client.post(
            f"/api/v1/grievances/{grievance_id}/clarification",
            json={"response_text": "Near Government High School junction, Ward 5, house #42."},
            headers=cit_headers,
        )
        assert citizen_clarify_res.status_code == 200
        assert citizen_clarify_res.json()["status"] in ("under_analysis", "under_processing")

        # 9. Official marks grievance as RESOLVED
        resolve_res = await client.post(
            f"/api/v1/official/grievances/{grievance_id}/action",
            json={
                "new_status": "resolved",
                "remarks": "Pipe leak repaired successfully by KWA maintenance team.",
            },
            headers=off_headers,
        )
        assert resolve_res.status_code == 200
        assert resolve_res.json()["status"] == "resolved"

        # 10. Audit log verification
        async with AsyncSessionLocal() as db:
            logs = (
                await db.execute(
                    select(GrievanceAuditLog)
                    .where(GrievanceAuditLog.grievance_id == grievance_id)
                    .order_by(GrievanceAuditLog.created_at.asc())
                )
            ).scalars().all()

            action_types = [l.action_type for l in logs]
            assert "ADMINISTRATIVE_ASSIGNMENT_EXECUTED" in action_types
            assert "OFFICIAL_ACTION_SUBMITTED" in action_types
            assert "CITIZEN_CLARIFICATION_SUBMITTED" in action_types
