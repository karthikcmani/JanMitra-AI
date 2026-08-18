import asyncio
import time
import pytest
from httpx import ASGITransport, AsyncClient
from app.main import app


@pytest.mark.asyncio
async def test_official_sprint6_features():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        ts = int(time.time())

        # 1. Register & Authenticate Citizen
        citizen_res = await client.post(
            "/api/v1/auth/register",
            json={
                "full_name": "Sprint6 Citizen",
                "email": f"sprint6_citizen_{ts}@janmitra.in",
                "phone": "9876543210",
                "password": "Password123!",
                "role": "citizen",
            },
        )
        assert citizen_res.status_code == 201
        token_cit = (
            await client.post(
                "/api/v1/auth/login",
                json={
                    "email": f"sprint6_citizen_{ts}@janmitra.in",
                    "password": "Password123!",
                },
            )
        ).json()["access_token"]
        headers_cit = {"Authorization": f"Bearer {token_cit}"}

        # 2. Register & Authenticate Official
        official_res = await client.post(
            "/api/v1/auth/register",
            json={
                "full_name": "Sprint6 Official Officer",
                "email": f"sprint6_official_{ts}@gov.in",
                "phone": "9123456789",
                "password": "OfficialPass123!",
                "role": "official",
            },
        )
        assert official_res.status_code == 201
        token_off = (
            await client.post(
                "/api/v1/auth/login",
                json={
                    "email": f"sprint6_official_{ts}@gov.in",
                    "password": "OfficialPass123!",
                },
            )
        ).json()["access_token"]
        headers_off = {"Authorization": f"Bearer {token_off}"}

        # 3. Security Role Verification
        res_sec = await client.get("/api/v1/official/dashboard/summary", headers=headers_cit)
        assert res_sec.status_code == 403, "Citizen must receive 403 on official summary dashboard"

        # 4. Official Dashboard Summary
        summary_res = await client.get("/api/v1/official/dashboard/summary", headers=headers_off)
        assert summary_res.status_code == 200
        summary_data = summary_res.json()
        assert "total_grievances" in summary_data
        assert "pending" in summary_data
        assert "high_priority" in summary_data
        assert "recent_grievances" in summary_data

        # 5. Create Grievance to Search
        draft_res = await client.post(
            "/api/v1/grievances/intake/draft",
            json={
                "title": "Broken Water Pipe in Ward 9",
                "description": "Clean drinking water leaking heavily near KWA pump house.",
                "priority": "high",
            },
            headers=headers_cit,
        )
        assert draft_res.status_code == 201
        grv_id = draft_res.json()["id"]

        # 6. Official Search & Filtering
        search_res = await client.get(
            "/api/v1/official/grievances/search",
            params={"query": "Water Pipe", "priority": "high"},
            headers=headers_off,
        )
        assert search_res.status_code == 200
        search_results = search_res.json()
        assert len(search_results) >= 1
        assert any(g["id"] == grv_id for g in search_results)

        # 7. Decision Support Panel Verification
        single_grv = search_results[0]
        assert "decision_support" in single_grv
        assert single_grv["decision_support"] is not None
        assert "suggested_department" in single_grv["decision_support"]
        assert "disclaimer" in single_grv["decision_support"]
        assert "AI-assisted" in single_grv["decision_support"]["disclaimer"]

        # 8. Attention Queue Verification
        attn_res = await client.get("/api/v1/official/grievances/attention-queue", headers=headers_off)
        assert attn_res.status_code == 200
        attn_data = attn_res.json()
        assert len(attn_data) >= 1

        # 9. Admin Department Workload Verification
        workload_res = await client.get("/api/v1/official/admin/department-workload", headers=headers_off)
        assert workload_res.status_code == 200
        workload_data = workload_res.json()
        assert len(workload_data) >= 4
        assert any(w["department_name"] == "Kerala Water Authority (KWA)" for w in workload_data)
