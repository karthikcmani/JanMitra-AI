import asyncio
import time
from httpx import ASGITransport, AsyncClient
import pytest
from app.main import app


@pytest.mark.asyncio
async def test_duplicate_check_and_profile_update():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        ts = int(time.time())
        email = f"citizen_dup_{ts}@gov.in"
        password = "Password123!"

        # 1. Register & Login Citizen
        reg_res = await client.post(
            "/api/v1/auth/register",
            json={
                "full_name": "Original Citizen Name",
                "email": email,
                "phone": "9876543210",
                "password": password,
                "role": "citizen",
            },
        )
        assert reg_res.status_code == 201
        token_res = await client.post(
            "/api/v1/auth/login",
            json={"email": email, "password": password},
        )
        assert token_res.status_code == 200
        token = token_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # 2. Test Profile Update (PUT /auth/profile)
        update_res = await client.put(
            "/api/v1/auth/profile",
            json={
                "full_name": "Updated Citizen Name",
                "phone": "9123456789",
            },
            headers=headers,
        )
        assert update_res.status_code == 200, f"Profile update failed: {update_res.text}"
        updated_data = update_res.json()
        assert updated_data["full_name"] == "Updated Citizen Name"
        assert updated_data["phone"] == "9123456789"

        # Verify via GET /auth/me
        me_res = await client.get("/api/v1/auth/me", headers=headers)
        assert me_res.status_code == 200
        assert me_res.json()["full_name"] == "Updated Citizen Name"

        # 3. Create an active grievance
        draft_res = await client.post(
            "/api/v1/grievances/intake/draft",
            json={
                "title": "Severe Water Pipe Leakage in Ward 14",
                "intake_mode": "direct_text",
                "original_language": "ml",
                "original_text": "വാർഡ് 14-ൽ പ്രധാന കുടിവെള്ള പൈപ്പ് പൊട്ടി വെള്ളം പാഴാകുന്നു.",
            },
            headers=headers,
        )
        assert draft_res.status_code == 201
        active_gid = draft_res.json()["id"]

        # 4. Test Duplicate Detection: Identical/Similar Title & Content
        dup_check_res = await client.post(
            "/api/v1/grievances/check-duplicate",
            json={
                "title": "Severe Water Pipe Leakage in Ward 14",
                "text": "വാർഡ് 14-ൽ പ്രധാന കുടിവെള്ള പൈപ്പ് പൊട്ടി വെള്ളം പാഴാകുന്നു.",
            },
            headers=headers,
        )
        assert dup_check_res.status_code == 200
        dup_data = dup_check_res.json()
        assert dup_data["is_duplicate"] is True
        assert dup_data["existing_grievance_id"] == active_gid
        assert dup_data["similarity_score"] > 0.4

        # 5. Test Non-Duplicate Check: Completely different topic
        diff_check_res = await client.post(
            "/api/v1/grievances/check-duplicate",
            json={
                "title": "Street light failure near school",
                "text": "സ്ട്രീറ്റ് ലൈറ്റ് പ്രവർത്തിക്കുന്നില്ല രാത്രിയിൽ ഇരുട്ടാണ്.",
            },
            headers=headers,
        )
        assert diff_check_res.status_code == 200
        diff_data = diff_check_res.json()
        assert diff_data["is_duplicate"] is False
