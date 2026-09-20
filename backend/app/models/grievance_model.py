import uuid
from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy import Boolean, Float, ForeignKey, Integer, JSON, String, Text, DateTime
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database.session import Base


class ExtractionStatus:
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    NEEDS_VERIFICATION = "needs_verification"
    FAILED = "failed"


class GrievanceStatus:
    DRAFT = "draft"
    INTAKE_RECEIVED = "intake_received"
    CITIZEN_VERIFIED = "citizen_verified"
    GROUPING_CONFIRMED = "grouping_confirmed"
    AI_ANALYSIS_INTERVIEW = "ai_analysis_interview"
    UNDER_ANALYSIS = "under_analysis"
    FINALIZED = "finalized"
    AUTHORITY_RECOMMENDED = "authority_recommended"
    ADMINISTRATIVE_REVIEW = "administrative_review"
    FORWARDED = "forwarded"
    UNDER_PROCESSING = "under_processing"
    CLARIFICATION_REQUIRED = "clarification_required"
    RESOLVED = "resolved"
    CLOSED = "closed"


class IntakeMode:
    DIRECT_TEXT = "direct_text"
    OCR_HANDWRITTEN = "ocr_handwritten"
    VOICE_STT = "voice_stt"


class AttachmentType:
    HANDWRITTEN_PETITION = "handwritten_petition"
    SCANNED_DOCUMENT = "scanned_document"
    VOICE_RECORDING = "voice_recording"
    SUPPORTING_EVIDENCE = "supporting_evidence"


class InterviewStatus:
    NOT_REQUIRED = "not_required"
    NEEDS_INTERVIEW = "needs_interview"
    IN_PROGRESS = "in_progress"
    WAITING_FOR_CITIZEN = "waiting_for_citizen"
    COMPLETED = "completed"


class Grievance(Base):
    __tablename__ = "grievances"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        index=True,
    )
    grievance_number: Mapped[str] = mapped_column(
        String(50),
        unique=True,
        index=True,
        nullable=False,
    )
    citizen_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    title: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    intake_mode: Mapped[str] = mapped_column(
        String(50),
        default=IntakeMode.DIRECT_TEXT,
        nullable=False,
    )
    original_language: Mapped[str] = mapped_column(
        String(20),
        default="ml",
        nullable=False,
    )
    original_text: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    translated_text: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(
        String(50),
        default=GrievanceStatus.DRAFT,
        nullable=False,
    )
    priority: Mapped[str] = mapped_column(
        String(20),
        default="medium",
        nullable=False,
    )
    severity: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    summary: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Sprint 11 AI Processing fields
    ai_processing_status: Mapped[Optional[str]] = mapped_column(
        String(50), default="pending", nullable=True
    )
    ai_processed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    ai_model: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    ai_error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    confirmed_location: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    location_sources: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    category: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    department_id: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    assigned_official_id: Mapped[Optional[str]] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    citizen = relationship("User", foreign_keys=[citizen_id], back_populates="grievances")
    assigned_official = relationship("User", foreign_keys=[assigned_official_id])
    attachments: Mapped[List["GrievanceAttachment"]] = relationship(
        "GrievanceAttachment",
        back_populates="grievance",
        cascade="all, delete-orphan",
        lazy="selectin",
    )
    audit_logs: Mapped[List["GrievanceAuditLog"]] = relationship(
        "GrievanceAuditLog",
        back_populates="grievance",
        cascade="all, delete-orphan",
        lazy="selectin",
    )
    analysis: Mapped[Optional["GrievanceAnalysis"]] = relationship(
        "GrievanceAnalysis",
        uselist=False,
        back_populates="grievance",
        cascade="all, delete-orphan",
        lazy="selectin",
    )
    issues: Mapped[List["GrievanceIssue"]] = relationship(
        "GrievanceIssue",
        back_populates="grievance",
        cascade="all, delete-orphan",
        lazy="selectin",
    )
    interview_questions: Mapped[List["GrievanceInterviewQuestion"]] = relationship(
        "GrievanceInterviewQuestion",
        back_populates="grievance",
        cascade="all, delete-orphan",
        lazy="selectin",
    )
    interview_responses: Mapped[List["GrievanceInterviewResponse"]] = relationship(
        "GrievanceInterviewResponse",
        back_populates="grievance",
        cascade="all, delete-orphan",
        lazy="selectin",
    )
    ai_runs: Mapped[List["GrievanceAIRun"]] = relationship(
        "GrievanceAIRun",
        back_populates="grievance",
        cascade="all, delete-orphan",
        lazy="selectin",
    )


class GrievanceIssue(Base):
    __tablename__ = "grievance_issues"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        index=True,
    )
    grievance_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("grievances.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    issue_number: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    category: Mapped[str] = mapped_column(String(150), nullable=False)
    subcategory: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    severity: Mapped[str] = mapped_column(String(50), default="MEDIUM", nullable=False)
    priority: Mapped[str] = mapped_column(String(50), default="MEDIUM", nullable=False)
    status: Mapped[str] = mapped_column(String(50), default="OPEN", nullable=False)
    extracted_facts: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    interview_status: Mapped[str] = mapped_column(
        String(50), default=InterviewStatus.NOT_REQUIRED, nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    grievance = relationship("Grievance", back_populates="issues")
    questions = relationship("GrievanceInterviewQuestion", back_populates="issue", cascade="all, delete-orphan")


class GrievanceInterviewQuestion(Base):
    __tablename__ = "grievance_interview_questions"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        index=True,
    )
    grievance_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("grievances.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    issue_id: Mapped[Optional[str]] = mapped_column(
        String(36),
        ForeignKey("grievance_issues.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    question: Mapped[str] = mapped_column(Text, nullable=False)
    question_type: Mapped[str] = mapped_column(String(50), default="TEXT", nullable=False)
    required: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    order_index: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    status: Mapped[str] = mapped_column(String(50), default="PENDING", nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    grievance = relationship("Grievance", back_populates="interview_questions")
    issue = relationship("GrievanceIssue", back_populates="questions")
    responses = relationship("GrievanceInterviewResponse", back_populates="question", cascade="all, delete-orphan")


class GrievanceInterviewResponse(Base):
    __tablename__ = "grievance_interview_responses"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        index=True,
    )
    question_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("grievance_interview_questions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    issue_id: Mapped[Optional[str]] = mapped_column(
        String(36),
        ForeignKey("grievance_issues.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    grievance_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("grievances.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    response_text: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    grievance = relationship("Grievance", back_populates="interview_responses")
    question = relationship("GrievanceInterviewQuestion", back_populates="responses")


class GrievanceAIRun(Base):
    __tablename__ = "grievance_ai_runs"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        index=True,
    )
    grievance_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("grievances.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    operation: Mapped[str] = mapped_column(String(100), nullable=False)
    model: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    status: Mapped[str] = mapped_column(String(50), default="PENDING", nullable=False)
    input_summary: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    output_data: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    completed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    grievance = relationship("Grievance", back_populates="ai_runs")


class GrievanceAttachment(Base):
    __tablename__ = "grievance_attachments"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        index=True,
    )
    grievance_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("grievances.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    attachment_type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
    )
    original_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    mime_type: Mapped[str] = mapped_column(String(100), nullable=False)
    storage_path: Mapped[str] = mapped_column(String(500), nullable=False)
    file_size_bytes: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    raw_extracted_text: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    extraction_status: Mapped[str] = mapped_column(
        String(50),
        default=ExtractionStatus.PENDING,
        server_default=ExtractionStatus.PENDING,
        nullable=False,
    )
    extraction_confidence: Mapped[Optional[float]] = mapped_column(
        Float, nullable=True
    )
    extraction_engine: Mapped[Optional[str]] = mapped_column(
        String(100), nullable=True
    )
    extraction_error: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    extracted_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    grievance = relationship("Grievance", back_populates="attachments")


class GrievanceAuditLog(Base):
    __tablename__ = "grievance_audit_logs"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        index=True,
    )
    grievance_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("grievances.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    actor_id: Mapped[Optional[str]] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    actor_role: Mapped[str] = mapped_column(
        String(50),
        default="citizen",
        nullable=False,
    )
    action_type: Mapped[str] = mapped_column(String(50), nullable=False)
    previous_state: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    new_state: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    remarks: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    grievance = relationship("Grievance", back_populates="audit_logs")
    actor = relationship("User")


class GrievanceAnalysis(Base):
    __tablename__ = "grievance_analysis"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
        index=True,
    )
    grievance_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("grievances.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    extracted_entities: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    predicted_category: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    legal_grounding_references: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    ai_explanation: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    grievance = relationship("Grievance", back_populates="analysis")
