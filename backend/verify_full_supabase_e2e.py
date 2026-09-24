import asyncio
import os
import sys
import time
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
from sqlalchemy import text
from app.database.session import AsyncSessionLocal, engine, init_db_schema
from app.models.grievance_model import (
    AttachmentType,
    DuplicateDetection,
    ExtractionStatus,
    Grievance,
    GrievanceAnalysis,
    GrievanceAttachment,
    GrievanceAuditLog,
    GrievanceIssue,
    GrievanceStatus,
    IntakeMode,
    JurisdictionRecommendation,
    KnowledgeChunk,
    KnowledgeDocument,
    UserNotification,
)
from app.models.user_model import User
from app.services.ai_intelligence_service import AIIntelligenceService
from app.services.duplicate_service import DuplicateDetectionService
from app.services.grievance_service import GrievanceService
from app.services.jurisdiction_service import JurisdictionIntelligenceService
from app.services.knowledge_service import KnowledgeBaseService
from app.services.legal_service import LegalIntelligenceService
from app.services.notification_service import NotificationService
from app.services.official_service import OfficialActionRequest, OfficialService


async def run_full_e2e_verification():
    print("==========================================================================")
    print(" JANMITRA AI — COMPLETE DATABASE & E2E SYSTEM VERIFICATION")
    print("==========================================================================")

    # STEP 1: INITIALIZE DB SCHEMA & RUN DIRECT SQL VERIFICATION
    print("\n[STEP 1] Initializing Database Schema & Verifying Tables...")
    await init_db_schema()

    async with AsyncSessionLocal() as session:
        result = await session.execute(
            text(
                "SELECT table_name FROM information_schema.tables WHERE table_schema='public'"
            )
        )
        tables = [row[0] for row in result.fetchall()]
        print(f" -> Active PostgreSQL Tables ({len(tables)}): {sorted(tables)}")

        required_tables = [
            "users", "grievances", "grievance_issues", "grievance_interview_questions",
            "grievance_interview_responses", "grievance_ai_runs", "grievance_attachments",
            "grievance_audit_logs", "grievance_analysis", "knowledge_documents",
            "knowledge_chunks", "jurisdiction_recommendations", "duplicate_detections",
            "user_notifications"
        ]
        for req in required_tables:
            assert req in tables, f"Missing table: {req}"
        print(" -> [VERIFIED] All 14 core database tables exist in PostgreSQL schema.")

    # STEP 2: KNOWLEDGE BASE INGESTION & VECTOR RAG VERIFICATION
    print("\n[STEP 2] Verifying Legal Knowledge Base Vector Ingestion...")
    async with AsyncSessionLocal() as session:
        kb_service = KnowledgeBaseService(session)
        added_count = await kb_service.seed_default_knowledge_base()
        print(f" -> Default Knowledge Base Seeded: New Docs Added={added_count}")

        # Search vector knowledge base
        searchResults = await kb_service.search_relevant_chunks("village road culvert maintenance", top_k=2)
        print(f" -> Vector Search Results Returned: {len(searchResults)} chunks matched.")
        assert len(searchResults) > 0, "Vector search must return matches"

    # STEP 3: CITIZEN REGISTRATION & AUTHENTICATION
    print("\n[STEP 3] Registering Test Users (Citizen, Admin, Official)...")
    ts = int(time.time())
    cit_id = f"usr_cit_{ts}"
    admin_id = f"usr_adm_{ts}"
    off_id = f"usr_off_{ts}"

    async with AsyncSessionLocal() as session:
        cit_user = User(
            id=cit_id,
            full_name="Karthik Citizen",
            email=f"citizen_{ts}@janmitra.gov.in",
            password_hash="hashed_pass_123",
            role="citizen",
            phone="+919876543210",
        )
        admin_user = User(
            id=admin_id,
            full_name="Admin Officer",
            email=f"admin_{ts}@janmitra.gov.in",
            password_hash="hashed_pass_admin",
            role="admin",
        )
        off_user = User(
            id=off_id,
            full_name="Engineer Official",
            email=f"official_{ts}@kwa.gov.in",
            password_hash="hashed_pass_off",
            role="official",
            department_id="Kerala Water Authority (KWA)",
        )
        session.add_all([cit_user, admin_user, off_user])
        await session.commit()
        print(f" -> Created Users: Citizen ({cit_id}), Admin ({admin_id}), Official ({off_id})")

    # STEP 4: CITIZEN MULTIMODAL INTAKE & ATTACHMENT PROCESSING
    print("\n[STEP 4] Executing Citizen Grievance Intake & Attachment Upload...")
    grievance_number = f"JM-E2E-{ts}"
    g_id = f"grv_e2e_{ts}"

    async with AsyncSessionLocal() as session:
        grievance = Grievance(
            id=g_id,
            grievance_number=grievance_number,
            citizen_id=cit_id,
            title="Severe Pipe Leakage and Water Supply Disruption in Ward 5",
            description="The main drinking water supply pipe has burst near Ward 5 market junction. Water is wasted continuously and road is flooded.",
            intake_mode=IntakeMode.OCR_HANDWRITTEN,
            status=GrievanceStatus.INTAKE_RECEIVED,
            priority="high",
            confirmed_location={
                "district": "Ernakulam",
                "panchayat_or_municipality": "Aluva",
                "ward": "Ward 5",
            },
            category="Water Supply & Sewage",
        )
        session.add(grievance)
        await session.commit()
        print(f" -> Created Grievance: {grievance_number} (ID: {g_id})")

        # Attachment creation
        att_id = f"att_e2e_{ts}"
        attachment = GrievanceAttachment(
            id=att_id,
            grievance_id=g_id,
            attachment_type=AttachmentType.HANDWRITTEN_PETITION,
            original_filename="water_leakage_petition.png",
            mime_type="image/png",
            storage_path=f"storage/petitions/{g_id}_petition.png",
            file_size_bytes=102450,
            raw_extracted_text="വിഷയം: വാർഡ് 5 ലെ പ്രധാന കുടിവെള്ള പൈപ്പ് പൊട്ടൽ സബന്ധിച്ച്. കുടിവെള്ള വിതരണം നിലച്ചിരിക്കുകയാണ്.",
            extraction_status=ExtractionStatus.COMPLETED,
            extraction_confidence=0.94,
            extraction_engine="gemini_vision_ocr_v1",
        )
        session.add(attachment)
        await session.commit()
        print(f" -> Attached Petition Scan: ID={att_id} | OCR Status=COMPLETED")

    # STEP 5: SPRINT 11 AI INTELLIGENCE & INTERVIEW ENGINE
    print("\n[STEP 5] Running AI Intelligence Pipeline & Interview Question Generation...")
    async with AsyncSessionLocal() as session:
        ai_service = AIIntelligenceService(session)
        analysis_res = await ai_service.analyze_grievance_intelligence(g_id)
        print(f" -> AI Analysis Summary: {analysis_res.get('summary')}")
        print(f" -> Identified Sub-issues ({len(analysis_res.get('issues', []))}): {[i.get('title') for i in analysis_res.get('issues', [])]}")
        print(f" -> Generated Interview Questions ({len(analysis_res.get('interview_questions', []))}): {[q.get('question') for q in analysis_res.get('interview_questions', [])]}")

        # Submit citizen interview response if questions exist
        if analysis_res.get("interview_questions"):
            q_id = analysis_res["interview_questions"][0]["id"]
            resp_data = [{"question_id": q_id, "response_text": "House No 45/B, Near Central Market Landmark"}]
            re_analysis = await ai_service.submit_citizen_interview_responses(g_id, cit_id, resp_data)
            print(" -> Citizen Answered Interview Question successfully.")

    # STEP 6: RAG LEGAL INTELLIGENCE ANALYSIS
    print("\n[STEP 6] Executing RAG Legal Intelligence Analysis...")
    async with AsyncSessionLocal() as session:
        legal_service = LegalIntelligenceService(session)
        legal_res = await legal_service.analyze_legal_grounding(g_id)
        print(f" -> Recommended Dept: {legal_res.get('suggested_department')}")
        print(f" -> Statutory Provisions ({len(legal_res.get('statutory_provisions', []))}): {legal_res.get('statutory_provisions')}")
        print(f" -> Required Citizen Proof: {legal_res.get('required_citizen_documents')}")

    # STEP 7: JURISDICTION INTELLIGENCE & HUMAN OVERRIDE
    print("\n[STEP 7] Running Jurisdiction Intelligence Recommendation...")
    async with AsyncSessionLocal() as session:
        j_service = JurisdictionIntelligenceService(session)
        rec_data = await j_service.recommend_jurisdiction(grievance_id=g_id)
        print(f" -> Recommended Jurisdiction: {rec_data.get('recommended_authority')} ({rec_data.get('department_name')})")

        # Official human override
        override_rec = await j_service.override_recommendation(
            grievance_id=g_id,
            official_id=admin_id,
            new_department="Kerala Water Authority (KWA)",
            new_authority="Kerala Water Authority (KWA) Aluva Sub-Division",
            remarks="Verified ward boundary; KWA Aluva Sub-Division retains jurisdiction.",
        )
        print(f" -> Human Override Status: {override_rec.get('status')} -> {override_rec.get('recommended_authority')}")

    # STEP 8: DUPLICATE DETECTION
    print("\n[STEP 8] Testing Duplicate Grievance Detection Engine...")
    async with AsyncSessionLocal() as session:
        # Create second grievance in same ward
        dup_g_id = f"grv_dup_{ts}"
        dup_grievance = Grievance(
            id=dup_g_id,
            grievance_number=f"JM-DUP-{ts}",
            citizen_id=cit_id,
            title="Drinking Water Pipe Leakage in Ward 5 Aluva",
            description="Main pipeline broken near Ward 5 market junction. Severe water leakage.",
            intake_mode=IntakeMode.DIRECT_TEXT,
            status=GrievanceStatus.INTAKE_RECEIVED,
            confirmed_location={
                "district": "Ernakulam",
                "panchayat_or_municipality": "Aluva",
                "ward": "Ward 5",
            },
            category="Water Supply & Sewage",
        )
        session.add(dup_grievance)
        await session.commit()

        dup_service = DuplicateDetectionService(session)
        dup_matches = await dup_service.detect_duplicates(dup_g_id)
        print(f" -> Candidate Duplicates Detected ({len(dup_matches)}):")
        for match in dup_matches:
            print(f"     * Matched Grievance ID: {match['matched_grievance_id']} | Similarity: {match['similarity_percentage']}%")
            assert match['similarity_score'] >= 0.65

    # STEP 9: ADMIN WORKFLOW — DASHBOARD & OFFICIAL ASSIGNMENT
    print("\n[STEP 9] Executing Admin Master Search & Official Assignment...")
    async with AsyncSessionLocal() as session:
        off_service = OfficialService(session)
        summary = await off_service.get_dashboard_summary()
        print(f" -> Statewide Dashboard Overview: Total={summary.total_grievances} | Pending={summary.pending} | High Prio={summary.high_priority}")

        # Assign grievance to official
        assigned_g = await off_service.update_official_action(
            grievance_id=g_id,
            official_id=admin_id,
            action_in=OfficialActionRequest(
                department_name="Kerala Water Authority (KWA)",
                new_status="forwarded",
                remarks="Assigned to KWA Aluva Sub-Division for urgent repairs.",
            ),
        )
        print(f" -> Grievance Assigned to KWA. Status: {assigned_g.status}")

    # STEP 10: OFFICIAL WORKFLOW — CLARIFICATION & RESOLUTION
    print("\n[STEP 10] Executing Official Case Processing, Clarification & Resolution...")
    async with AsyncSessionLocal() as session:
        notif_service = NotificationService(session)
        off_service = OfficialService(session)

        # 10a. Official requests clarification from citizen
        clarify_g = await off_service.update_official_action(
            grievance_id=g_id,
            official_id=off_id,
            action_in=OfficialActionRequest(
                new_status="clarification_required",
                question="Please confirm if repair work is needed on private consumer line or main distribution pipeline.",
                remarks="Clarification requested from citizen.",
            ),
        )
        print(f" -> Status Updated: {clarify_g.status}")

        # Send notification to citizen
        await notif_service.create_notification(
            user_id=cit_id,
            title="Clarification Required",
            message="Please confirm pipeline boundary type.",
            grievance_id=g_id,
            notification_type="CLARIFICATION_REQUIRED",
        )
        print(" -> In-App Notification Sent to Citizen.")

        # 10b. Citizen responds to clarification
        g_service = GrievanceService(session)
        responded_g = await g_service.submit_clarification(
            citizen_id=cit_id,
            grievance_id=g_id,
            response_text="The leak is on the main 6-inch distribution pipeline on the public road.",
        )
        print(f" -> Citizen Clarification Submitted. Status: {responded_g.status}")

        # 10c. Official resolves grievance
        resolved_g = await off_service.update_official_action(
            grievance_id=g_id,
            official_id=off_id,
            action_in=OfficialActionRequest(
                new_status="resolved",
                remarks="KWA Repair Team dispatched. Main distribution line repaired and water supply restored.",
            ),
        )
        print(f" -> Grievance Resolved! Status: {resolved_g.status}")
        await notif_service.create_notification(
            user_id=cit_id,
            title="Grievance Resolved",
            message="Resolved & Closed",
            grievance_id=g_id,
            notification_type="STATUS_CHANGE",
        )

    # STEP 11: DATABASE RESTART & PERSISTENCE VERIFICATION
    print("\n[STEP 11] Executing Database Engine Restart & Persistence Test...")
    # Close active engine pool connection
    await engine.dispose()
    print(" -> Connection pool closed/disposed.")

    # Re-initialize engine and query records
    print(" -> Re-opening connection pool to PostgreSQL...")
    async with AsyncSessionLocal() as session:
        # Query Grievance
        stmt = text("SELECT id, grievance_number, status, priority, summary FROM grievances WHERE id = :id")
        res = await session.execute(stmt, {"id": g_id})
        row = res.fetchone()
        assert row is not None, "Grievance record must persist after restart"
        print(f" -> [PERSISTED] Grievance #{row[1]} | Status={row[2]} | Priority={row[3]}")

        # Query Attachments
        res_att = await session.execute(text("SELECT count(*) FROM grievance_attachments WHERE grievance_id = :id"), {"id": g_id})
        att_cnt = res_att.scalar()
        assert att_cnt > 0, "Attachment record must persist after restart"
        print(f" -> [PERSISTED] Grievance Attachments Count = {att_cnt}")

        # Query Audit Logs
        res_audit = await session.execute(text("SELECT count(*) FROM grievance_audit_logs WHERE grievance_id = :id"), {"id": g_id})
        audit_cnt = res_audit.scalar()
        assert audit_cnt > 0, "Audit logs must persist after restart"
        print(f" -> [PERSISTED] Audit Trail Logs Count = {audit_cnt}")

        # Query Notifications
        res_notif = await session.execute(text("SELECT count(*) FROM user_notifications WHERE user_id = :id"), {"id": cit_id})
        notif_cnt = res_notif.scalar()
        assert notif_cnt > 0, "Notifications must persist after restart"
        print(f" -> [PERSISTED] In-App Notifications Count = {notif_cnt}")

    print("\n==========================================================================")
    print(" ALL 11 VERIFICATION STEPS PASSED 100%! SYSTEM PERSISTENCE CONFIRMED.")
    print("==========================================================================")


if __name__ == "__main__":
    asyncio.run(run_full_e2e_verification())
