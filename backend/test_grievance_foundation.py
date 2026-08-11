import asyncio
import time
import uuid
from datetime import datetime, timezone
import pytest
from sqlalchemy import select
from app.database.session import AsyncSessionLocal
from app.models import (
    User,
    Grievance,
    GrievanceAttachment,
    GrievanceAuditLog,
    GrievanceStatus,
    IntakeMode,
    AttachmentType,
)


@pytest.mark.asyncio
async def test_grievance_foundation_flow():
    async with AsyncSessionLocal() as session:
        print("--- 1. Creating Authenticated User ---")
        timestamp = int(time.time())
        user_id = str(uuid.uuid4())
        user = User(
            id=user_id,
            full_name="Ananya Nair",
            email=f"ananya_{timestamp}@gov.in",
            phone="9876543210",
            password_hash="hashed_secret_password",
            role="citizen",
            is_active=True,
        )
        session.add(user)
        await session.commit()
        await session.refresh(user)
        print(f"Created User: {user.full_name} (id: {user.id})")

        print("\n--- 2. Creating Grievance Associated with User ---")
        grievance_id = str(uuid.uuid4())
        grievance_no = f"JM-2026-{timestamp}"
        grievance = Grievance(
            id=grievance_id,
            grievance_number=grievance_no,
            citizen_id=user.id,
            title="Drinking Water Disruption in Ward 5",
            description="Water supply halted for 3 consecutive days.",
            intake_mode=IntakeMode.OCR_HANDWRITTEN,
            original_language="ml",
            original_text="വാർഡ് 5 ൽ കുടിവെള്ള വിതരണം തടസ്സപ്പെട്ടു.",
            translated_text="Drinking water supply disrupted in Ward 5.",
            status=GrievanceStatus.DRAFT,
            priority="high",
            confirmed_location={"district": "Ernakulam", "ward": "5"},
        )
        session.add(grievance)
        await session.commit()
        await session.refresh(grievance)
        assert grievance.citizen_id == user.id
        assert grievance.status == GrievanceStatus.DRAFT
        print(
            f"Created Grievance: {grievance.grievance_number} | Status: {grievance.status}"
        )

        print("\n--- 3. Creating Grievance Attachment ---")
        attachment_id = str(uuid.uuid4())
        attachment = GrievanceAttachment(
            id=attachment_id,
            grievance_id=grievance.id,
            attachment_type=AttachmentType.HANDWRITTEN_PETITION,
            original_filename="petition_handwritten_page1.jpg",
            mime_type="image/jpeg",
            storage_path="/uploads/2026/08/petition_handwritten_page1.jpg",
            file_size_bytes=204800,
            raw_extracted_text="വാർഡ് 5 ൽ കുടിവെള്ള വിതരണം തടസ്സപ്പെട്ടു.",
        )
        session.add(attachment)
        await session.commit()
        await session.refresh(attachment)
        assert attachment.grievance_id == grievance.id
        print(
            f"Created Attachment: {attachment.original_filename} (type: {attachment.attachment_type})"
        )

        print("\n--- 4. Creating Audit Event & Testing Status Transition ---")
        prev_status = grievance.status
        new_status = GrievanceStatus.INTAKE_RECEIVED
        grievance.status = new_status
        grievance.updated_at = datetime.now(timezone.utc)

        audit_log = GrievanceAuditLog(
            id=str(uuid.uuid4()),
            grievance_id=grievance.id,
            actor_id=user.id,
            actor_role="citizen",
            action_type="status_changed",
            previous_state=prev_status,
            new_state=new_status,
            remarks="Intake petition scan successfully received.",
        )
        session.add(audit_log)
        await session.commit()
        await session.refresh(grievance)
        await session.refresh(audit_log)

        assert grievance.status == GrievanceStatus.INTAKE_RECEIVED
        assert audit_log.previous_state == GrievanceStatus.DRAFT
        assert audit_log.new_state == GrievanceStatus.INTAKE_RECEIVED
        print(
            f"Audit Log Created: {audit_log.action_type} | Transition: {audit_log.previous_state} -> {audit_log.new_state}"
        )

        print("\n--- 5. Testing Database Relationships & Cascade Delete ---")
        result = await session.execute(
            select(Grievance).where(Grievance.id == grievance_id)
        )
        fetched_g = result.scalar_one()
        await session.refresh(fetched_g, ["attachments", "audit_logs"])
        assert len(fetched_g.attachments) == 1
        assert len(fetched_g.audit_logs) == 1
        print(
            "Verified Grievance Relationships: 1 Attachment & 1 Audit Log linked."
        )

        # Test Cascade Delete of Grievance
        await session.delete(fetched_g)
        await session.commit()

        res_att = await session.execute(
            select(GrievanceAttachment).where(
                GrievanceAttachment.id == attachment_id
            )
        )
        assert res_att.scalar_one_or_none() is None

        res_audit = await session.execute(
            select(GrievanceAuditLog).where(
                GrievanceAuditLog.id == audit_log.id
            )
        )
        assert res_audit.scalar_one_or_none() is None
        print(
            "Verified Cascade Delete: Grievance deletion automatically cleaned attachments & audit logs."
        )

        print("\nPHASE 1A BACKEND FOUNDATION TESTS PASSED 100%!")


if __name__ == "__main__":
    asyncio.run(test_grievance_foundation_flow())
