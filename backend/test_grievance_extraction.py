import asyncio
import io
import time
from httpx import ASGITransport, AsyncClient
import pytest
from sqlalchemy import select
from app.database.session import AsyncSessionLocal
from app.main import app
from app.models.grievance_model import GrievanceAttachment, GrievanceAuditLog
from app.services.extraction_service import MockExtractionAdapter
from app.services.storage_service import LocalFileSystemStorage


@pytest.mark.asyncio
async def test_grievance_extraction_flow():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        timestamp_a = int(time.time())
        email_a = f"citizen_ext_a_{timestamp_a}@gov.in"
        password_a = "Password123!"

        timestamp_b = timestamp_a + 1
        email_b = f"citizen_ext_b_{timestamp_b}@gov.in"
        password_b = "Password123!"

        # Register & Login Citizen A
        reg_a = await client.post(
            "/api/v1/auth/register",
            json={
                "full_name": "Citizen Extraction A",
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

        # Register & Login Citizen B
        reg_b = await client.post(
            "/api/v1/auth/register",
            json={
                "full_name": "Citizen Extraction B",
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

        # Create Draft Grievance for Citizen A
        draft_res = await client.post(
            "/api/v1/grievances/intake/draft",
            json={"title": "Grievance for Extraction Testing"},
            headers=headers_a,
        )
        assert draft_res.status_code == 201
        grievance_a_id = draft_res.json()["id"]

        # Upload Valid Handwritten Petition JPEG
        jpeg_bytes = b"\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xFF\xDB\x00C\x00\x08"
        upload_res = await client.post(
            f"/api/v1/grievances/{grievance_a_id}/attachments",
            files={"file": ("petition_scan.jpg", io.BytesIO(jpeg_bytes), "image/jpeg")},
            headers=headers_a,
        )
        assert upload_res.status_code == 201
        att_a_id = upload_res.json()["id"]

        print("\n--- 1. Testing Unauthenticated Extraction Rejection ---")
        res_unauth = await client.post(
            f"/api/v1/grievances/{grievance_a_id}/attachments/{att_a_id}/extract"
        )
        assert res_unauth.status_code == 401
        print("Unauthenticated extraction attempt cleanly rejected with 401.")

        print("\n--- 2. Testing Unauthorized Extraction Rejection (Citizen B on Citizen A) ---")
        res_cross_ext = await client.post(
            f"/api/v1/grievances/{grievance_a_id}/attachments/{att_a_id}/extract",
            headers=headers_b,
        )
        assert res_cross_ext.status_code == 404
        print("Unauthorized extraction by Citizen B cleanly rejected with 404.")

        print("\n--- 3. Testing Authenticated Extraction Flow (Citizen A) ---")
        res_ext = await client.post(
            f"/api/v1/grievances/{grievance_a_id}/attachments/{att_a_id}/extract",
            headers=headers_a,
        )
        assert res_ext.status_code == 200, f"Extraction failed: {res_ext.text}"
        ext_data = res_ext.json()

        assert ext_data["extraction_status"] == "completed"
        assert ext_data["engine_name"] == "mock_ocr_v1"
        assert ext_data["confidence_score"] == 0.92
        assert "കുടിവെള്ള വിതരണം" in ext_data["extracted_text"]
        print("Mock Extraction output returned deterministic Malayalam text:", ext_data["extracted_text"])

        print("\n--- 4. Verifying Extraction Result Persisted in PostgreSQL ---")
        async with AsyncSessionLocal() as db_session:
            att_res = await db_session.execute(
                select(GrievanceAttachment).where(GrievanceAttachment.id == att_a_id)
            )
            att_db = att_res.scalar_one_or_none()
            assert att_db is not None
            assert att_db.extraction_status == "completed"
            assert att_db.raw_extracted_text == ext_data["extracted_text"]
            assert att_db.extraction_confidence == 0.92
            assert att_db.extraction_engine == "mock_ocr_v1"
            assert att_db.extracted_at is not None

            audit_res = await db_session.execute(
                select(GrievanceAuditLog).where(
                    GrievanceAuditLog.grievance_id == grievance_a_id,
                    GrievanceAuditLog.action_type == "extraction_completed",
                )
            )
            audit_entry = audit_res.scalar_one_or_none()
            assert audit_entry is not None
            print("PostgreSQL extraction fields & extraction_completed Audit Log confirmed!")

        print("\n--- 5. Verifying Original Stored Artifact File Integrity ---")
        storage = LocalFileSystemStorage()
        abs_file_path = storage.get_absolute_path(upload_res.json()["storage_path"])
        assert abs_file_path.exists()
        assert abs_file_path.read_bytes() == jpeg_bytes
        print("Original uploaded file on disk remains completely unchanged.")

        print("\n--- 6. Testing Extraction Failure & Disk Preservation ---")
        # Upload attachment with filename containing "fail_trigger"
        upload_fail = await client.post(
            f"/api/v1/grievances/{grievance_a_id}/attachments",
            files={"file": ("fail_trigger_doc.pdf", io.BytesIO(b"%PDF-1.4\n%%EOF"), "application/pdf")},
            headers=headers_a,
        )
        assert upload_fail.status_code == 201
        att_fail_id = upload_fail.json()["id"]

        res_fail_ext = await client.post(
            f"/api/v1/grievances/{grievance_a_id}/attachments/{att_fail_id}/extract",
            headers=headers_a,
        )
        assert res_fail_ext.status_code == 200
        fail_data = res_fail_ext.json()
        assert fail_data["extraction_status"] == "failed"
        assert fail_data["error_message"] is not None

        # Verify physical file on disk remains intact after failure
        abs_fail_path = storage.get_absolute_path(upload_fail.json()["storage_path"])
        assert abs_fail_path.exists()
        assert abs_fail_path.read_bytes() == b"%PDF-1.4\n%%EOF"

        async with AsyncSessionLocal() as db_session:
            att_fail_db = (
                await db_session.execute(
                    select(GrievanceAttachment).where(GrievanceAttachment.id == att_fail_id)
                )
            ).scalar_one_or_none()
            assert att_fail_db.extraction_status == "failed"
            assert att_fail_db.extraction_error is not None

            audit_fail = (
                await db_session.execute(
                    select(GrievanceAuditLog).where(
                        GrievanceAuditLog.grievance_id == grievance_a_id,
                        GrievanceAuditLog.action_type == "extraction_failed",
                    )
                )
            ).scalar_one_or_none()
            assert audit_fail is not None
        print("Simulated extraction failure correctly set status to 'failed', logged error, and preserved file on disk.")

        print("\n--- 7. Testing Direct Text Pipeline Normalization ---")
        direct_result = MockExtractionAdapter.process_direct_text(
            text="കുടിവെള്ള ക്ഷാമം പരിഹരിക്കണം", language="ml"
        )
        assert direct_result.source_type == "direct_text"
        assert direct_result.extraction_status == "completed"
        assert direct_result.confidence_score == 1.0
        assert direct_result.engine_name == "direct_input"
        print("Direct text intake successfully normalized into standard extraction representation!")

        print("\nALL PHASE 1D MULTIMODAL EXTRACTION TESTS PASSED 100%!")


if __name__ == "__main__":
    asyncio.run(test_grievance_extraction_flow())
