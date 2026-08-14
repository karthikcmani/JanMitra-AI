import uuid
from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy import Float, ForeignKey, Integer, JSON, String, Text, DateTime
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database.session import Base


class ExtractionStatus:
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


class GrievanceStatus:
    DRAFT = "draft"
    INTAKE_RECEIVED = "intake_received"
    CITIZEN_VERIFIED = "citizen_verified"
    GROUPING_CONFIRMED = "grouping_confirmed"
    AI_ANALYSIS_INTERVIEW = "ai_analysis_interview"
    FINALIZED = "finalized"
    AUTHORITY_RECOMMENDED = "authority_recommended"
    ADMINISTRATIVE_REVIEW = "administrative_review"
    FORWARDED = "forwarded"
    UNDER_PROCESSING = "under_processing"
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
    confirmed_location: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    location_sources: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
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

    citizen = relationship("User", back_populates="grievances")
    attachments: Mapped[List["GrievanceAttachment"]] = relationship(
        "GrievanceAttachment",
        back_populates="grievance",
        cascade="all, delete-orphan",
    )
    audit_logs: Mapped[List["GrievanceAuditLog"]] = relationship(
        "GrievanceAuditLog",
        back_populates="grievance",
        cascade="all, delete-orphan",
    )


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
