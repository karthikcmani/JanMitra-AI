import asyncio
import io
import time
from pathlib import Path
from unittest.mock import patch
from httpx import ASGITransport, AsyncClient
import pytest
from sqlalchemy import select
from app.database.session import AsyncSessionLocal
from app.main import app
from app.models.grievance_model import GrievanceAttachment, GrievanceAuditLog
from app.services.storage_service import LocalFileSystemStorage


@pytest.mark.asyncio
async def test_grievance_attachments_flow():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        timestamp_a = int(time.time())
        email_a = f"citizen_att_a_{timestamp_a}@gov.in"
        password_a = "Password123!"

        timestamp_b = timestamp_a + 1
        email_b = f"citizen_att_b_{timestamp_b}@gov.in"
        password_b = "Password123!"

        # Register & Login Citizen A
        reg_a = await client.post(
            "/api/v1/auth/register",
            json={
                "full_name": "Citizen Attachment A",
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
                "full_name": "Citizen Attachment B",
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
            json={"title": "Grievance for Attachment Testing"},
            headers=headers_a,
        )
        assert draft_res.status_code == 201
        grievance_a_id = draft_res.json()["id"]

        print("\n--- 1. Testing Valid JPEG Upload ---")
        jpeg_bytes = b"\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xFF\xDB\x00C\x00\x08"
        files_jpeg = {"file": ("petition_page1.jpg", io.BytesIO(jpeg_bytes), "image/jpeg")}
        res_jpeg = await client.post(
            f"/api/v1/grievances/{grievance_a_id}/attachments",
            files=files_jpeg,
            headers=headers_a,
        )
        assert res_jpeg.status_code == 201, f"JPEG upload failed: {res_jpeg.text}"
        att_jpeg_data = res_jpeg.json()
        assert att_jpeg_data["original_filename"] == "petition_page1.jpg"
        assert att_jpeg_data["mime_type"] == "image/jpeg"
        print("JPEG Upload successful:", att_jpeg_data["storage_path"])

        print("\n--- 2. Testing Valid PNG Upload ---")
        png_bytes = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89"
        files_png = {"file": ("document_scan.png", io.BytesIO(png_bytes), "image/png")}
        res_png = await client.post(
            f"/api/v1/grievances/{grievance_a_id}/attachments",
            files=files_png,
            headers=headers_a,
        )
        assert res_png.status_code == 201, f"PNG upload failed: {res_png.text}"
        att_png_data = res_png.json()
        assert att_png_data["mime_type"] == "image/png"
        print("PNG Upload successful:", att_png_data["storage_path"])

        print("\n--- 3. Testing Valid PDF Upload ---")
        pdf_bytes = b"%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF"
        files_pdf = {"file": ("official_petition.pdf", io.BytesIO(pdf_bytes), "application/pdf")}
        res_pdf = await client.post(
            f"/api/v1/grievances/{grievance_a_id}/attachments",
            files=files_pdf,
            headers=headers_a,
        )
        assert res_pdf.status_code == 201, f"PDF upload failed: {res_pdf.text}"
        att_pdf_data = res_pdf.json()
        assert att_pdf_data["mime_type"] == "application/pdf"
        print("PDF Upload successful:", att_pdf_data["storage_path"])

        print("\n--- 4. Testing Invalid File Types & Extension Mismatch Rejection ---")
        # Text file
        files_txt = {"file": ("malicious.txt", io.BytesIO(b"hello world"), "text/plain")}
        res_txt = await client.post(
            f"/api/v1/grievances/{grievance_a_id}/attachments",
            files=files_txt,
            headers=headers_a,
        )
        assert res_txt.status_code == 400

        # Extension mismatch (.exe declared as image/jpeg)
        files_mismatch = {"file": ("virus.exe", io.BytesIO(b"MZ123"), "image/jpeg")}
        res_mismatch = await client.post(
            f"/api/v1/grievances/{grievance_a_id}/attachments",
            files=files_mismatch,
            headers=headers_a,
        )
        assert res_mismatch.status_code == 400
        print("Invalid file types & extension mismatches cleanly rejected with 400.")

        print("\n--- 5. Testing Oversized File Rejection (>10MB) ---")
        oversized_bytes = b"0" * (10 * 1024 * 1024 + 1)  # 10MB + 1 byte
        files_large = {"file": ("huge_petition.pdf", io.BytesIO(oversized_bytes), "application/pdf")}
        res_large = await client.post(
            f"/api/v1/grievances/{grievance_a_id}/attachments",
            files=files_large,
            headers=headers_a,
        )
        assert res_large.status_code == 400
        print("Oversized file (>10MB) cleanly rejected with 400.")

        print("\n--- 6. Testing Unauthenticated Upload Rejection ---")
        res_unauth = await client.post(
            f"/api/v1/grievances/{grievance_a_id}/attachments",
            files={"file": ("unauth.jpg", io.BytesIO(jpeg_bytes), "image/jpeg")},
        )
        assert res_unauth.status_code == 401
        print("Unauthenticated upload attempt cleanly rejected with 401.")

        print("\n--- 7. Testing Unauthorized Upload to Another Citizen's Grievance ---")
        res_cross_upload = await client.post(
            f"/api/v1/grievances/{grievance_a_id}/attachments",
            files={"file": ("cross.jpg", io.BytesIO(jpeg_bytes), "image/jpeg")},
            headers=headers_b,
        )
        assert res_cross_upload.status_code == 404
        print("Citizen B upload to Citizen A's grievance rejected with 404.")

        print("\n--- 8. Testing Download & Unauthorized Retrieval ---")
        # Citizen A downloads own attachment
        res_dl = await client.get(
            f"/api/v1/grievances/{grievance_a_id}/attachments/{att_jpeg_data['id']}",
            headers=headers_a,
        )
        assert res_dl.status_code == 200
        assert res_dl.content == jpeg_bytes
        print("Citizen A successfully retrieved file contents matching original byte array!")

        # Citizen B attempts to download Citizen A's attachment
        res_cross_dl = await client.get(
            f"/api/v1/grievances/{grievance_a_id}/attachments/{att_jpeg_data['id']}",
            headers=headers_b,
        )
        assert res_cross_dl.status_code == 404
        print("Citizen B download of Citizen A's attachment rejected with 404.")

        print("\n--- 9. Verifying Metadata in PostgreSQL & File Existence in Physical Storage ---")
        storage = LocalFileSystemStorage()
        abs_file_path = storage.get_absolute_path(att_jpeg_data["storage_path"])
        assert abs_file_path.exists()
        assert abs_file_path.is_file()
        assert abs_file_path.read_bytes() == jpeg_bytes

        async with AsyncSessionLocal() as db_session:
            att_db_res = await db_session.execute(
                select(GrievanceAttachment).where(GrievanceAttachment.id == att_jpeg_data["id"])
            )
            att_db = att_db_res.scalar_one_or_none()
            assert att_db is not None
            assert att_db.grievance_id == grievance_a_id
            assert att_db.original_filename == "petition_page1.jpg"

            audit_res = await db_session.execute(
                select(GrievanceAuditLog).where(
                    GrievanceAuditLog.grievance_id == grievance_a_id,
                    GrievanceAuditLog.action_type == "attachment_added",
                )
            )
            audit_entries = audit_res.scalars().all()
            assert len(audit_entries) == 3
            print("Metadata confirmed in PostgreSQL & exact file contents confirmed on physical disk!")

        print("\n--- 10. Testing Storage Safety & Path Traversal Prevention ---")
        with pytest.raises(ValueError):
            await storage.save_file("../../etc", "passwd.jpg", io.BytesIO(jpeg_bytes))
        with pytest.raises(ValueError):
            storage.get_absolute_path("../../../windows/system32/cmd.exe")
        print("Path traversal attacks safely caught and rejected by storage abstraction.")

        print("\n--- 11. Testing Database Failure File Cleanup & File Storage Failure DB Protection ---")
        # Test 11a: Database failure causes file cleanup
        with patch(
            "app.repositories.grievance_repository.GrievanceRepository.create_attachment",
            side_effect=RuntimeError("Simulated Database Error"),
        ):
            res_db_fail = await client.post(
                f"/api/v1/grievances/{grievance_a_id}/attachments",
                files={"file": ("fail_clean.jpg", io.BytesIO(jpeg_bytes), "image/jpeg")},
                headers=headers_a,
            )
            assert res_db_fail.status_code == 500

        # Verify no file named "fail_clean.jpg" was orphaned on disk
        target_dir = storage.base_dir / grievance_a_id / "original"
        if target_dir.exists():
            orphaned_files = list(target_dir.glob("*fail_clean*"))
            assert len(orphaned_files) == 0
        print("Database failure successfully cleaned up orphaned file from disk!")

        # Test 11b: Storage failure prevents DB insertion
        with patch(
            "app.services.storage_service.LocalFileSystemStorage.save_file",
            side_effect=IOError("Simulated Storage Disk Full Error"),
        ):
            res_storage_fail = await client.post(
                f"/api/v1/grievances/{grievance_a_id}/attachments",
                files={"file": ("fail_storage.jpg", io.BytesIO(jpeg_bytes), "image/jpeg")},
                headers=headers_a,
            )
            assert res_storage_fail.status_code == 500

        async with AsyncSessionLocal() as db_session:
            fail_db_res = await db_session.execute(
                select(GrievanceAttachment).where(
                    GrievanceAttachment.original_filename == "fail_storage.jpg"
                )
            )
            assert fail_db_res.scalar_one_or_none() is None
        print("Storage failure cleanly prevented DB insertion!")

        print("\nALL PHASE 1C MULTIMODAL INTAKE STORAGE TESTS PASSED 100%!")


if __name__ == "__main__":
    asyncio.run(test_grievance_attachments_flow())
