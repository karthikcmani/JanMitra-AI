import asyncio
import time
import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select
from app.database.session import AsyncSessionLocal
from app.main import app
from app.models.grievance_model import Grievance, GrievanceIssue, GrievanceInterviewQuestion, GrievanceInterviewResponse
from app.services.ai_intelligence_service import AIIntelligenceService


@pytest.mark.asyncio
async def test_sprint11_intelligence_and_interview_engine():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        timestamp = int(time.time())
        email = f"citizen_sprint11_{timestamp}@gov.in"
        password = "Password123!"

        # 1. Register & Login
        reg_res = await client.post(
            "/api/v1/auth/register",
            json={
                "full_name": "Sprint11 Test Citizen",
                "email": email,
                "phone": "9876543219",
                "password": password,
                "role": "citizen",
            },
        )
        assert reg_res.status_code == 201, f"Registration failed: {reg_res.text}"

        login_res = await client.post(
            "/api/v1/auth/login",
            json={"email": email, "password": password},
        )
        assert login_res.status_code == 200, f"Login failed: {login_res.text}"
        token = login_res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # 2. Create Intake Draft Grievance
        draft_res = await client.post(
            "/api/v1/grievances/intake/draft",
            headers=headers,
            json={
                "title": "Road Repair & Water Leakage Issue",
                "intake_mode": "ocr_handwritten",
                "original_language": "en",
                "original_text": "There are severe potholes on Main Road near Ward 5 market and drinking water pipe is leaking continuously near bus stand.",
            },
        )
        assert draft_res.status_code == 201, f"Draft creation failed: {draft_res.text}"
        grievance_id = draft_res.json()["id"]

        # 3. Submit Verified Text -> Auto-triggers AI Intelligence Analysis
        verify_text = (
            "Severe potholes on Main Road near Ward 5 market causing traffic accidents. "
            "Also KWA drinking water pipeline is burst near the central bus stand."
        )
        verify_res = await client.post(
            f"/api/v1/grievances/{grievance_id}/verify",
            headers=headers,
            json={"verified_text": verify_text},
        )
        assert verify_res.status_code == 200, f"Verification failed: {verify_res.text}"
        g_data = verify_res.json()
        assert g_data["status"] in ("intake_received", "under_analysis")
        assert g_data["ai_processing_status"] in ("completed", "failed")

        # 4. Explicit Trigger via AI Router Endpoint
        analyze_res = await client.post(
            f"/api/v1/grievances/{grievance_id}/analyze-intelligence",
            headers=headers,
        )
        assert analyze_res.status_code == 200, f"Analyze router failed: {analyze_res.text}"
        g_analyzed = analyze_res.json()
        assert "issues" in g_analyzed
        assert "interview_questions" in g_analyzed

        # 5. Database Schema & Data Verification
        async with AsyncSessionLocal() as db:
            result = await db.execute(select(Grievance).where(Grievance.id == grievance_id))
            g_db = result.scalar_one_or_none()
            assert g_db is not None
            assert g_db.original_text is not None

            # Query persisted issues
            issues_result = await db.execute(
                select(GrievanceIssue).where(GrievanceIssue.grievance_id == grievance_id)
            )
            persisted_issues = issues_result.scalars().all()

            # Query persisted interview questions
            questions_result = await db.execute(
                select(GrievanceInterviewQuestion).where(GrievanceInterviewQuestion.grievance_id == grievance_id)
            )
            persisted_questions = questions_result.scalars().all()

            if g_db.ai_processing_status == "completed":
                assert len(persisted_issues) >= 1, "Expected at least 1 persistent issue entity"
                assert len(persisted_questions) >= 1, "Expected at least 1 persistent interview question"

        # 6. Citizen Submits Interview Responses (if questions generated)
        if len(g_analyzed.get("interview_questions", [])) > 0:
            q_id = g_analyzed["interview_questions"][0]["id"]
            resp_res = await client.post(
                f"/api/v1/grievances/{grievance_id}/interview/responses",
                headers=headers,
                json={
                    "responses": [
                        {
                            "question_id": q_id,
                            "response_text": "The water leak has been active for 4 days near Shop No 12.",
                        }
                    ]
                },
            )
            assert resp_res.status_code == 200, f"Interview response submit failed: {resp_res.text}"
            resp_data = resp_res.json()
            assert "interview_questions" in resp_data

            # Verify response DB record & append-only text
            async with AsyncSessionLocal() as db:
                responses_db = await db.execute(
                    select(GrievanceInterviewResponse).where(GrievanceInterviewResponse.grievance_id == grievance_id)
                )
                saved_resps = responses_db.scalars().all()
                assert len(saved_resps) >= 1
                assert saved_resps[0].response_text == "The water leak has been active for 4 days near Shop No 12."

                # Verify original text preserved intact append-only
                result = await db.execute(select(Grievance).where(Grievance.id == grievance_id))
                updated_g = result.scalar_one()
                assert verify_text in updated_g.original_text
                assert "[Citizen Interview Clarification Responses]:" in updated_g.original_text

        # 7. Fallback Test: AI Error handling without fake/mock data creation
        async with AsyncSessionLocal() as db:
            service = AIIntelligenceService(db)

            # Temporarily simulate AI service failure
            async def failing_call(*args, **kwargs):
                raise RuntimeError("API Quota Exhausted 429")

            service._call_gemini_intelligence = failing_call

            res = await service.analyze_grievance_intelligence(grievance_id)
            assert res is not None
            assert "summary" in res

            result = await db.execute(select(Grievance).where(Grievance.id == grievance_id))
            test_g = result.scalar_one()
            assert test_g.ai_processing_status == "completed"
