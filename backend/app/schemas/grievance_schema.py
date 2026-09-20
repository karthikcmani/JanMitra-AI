from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, ConfigDict, Field
from app.models.grievance_model import GrievanceStatus, IntakeMode


class GrievanceDraftCreate(BaseModel):
    title: Optional[str] = Field(None, max_length=255)
    description: Optional[str] = None
    intake_mode: str = Field(IntakeMode.DIRECT_TEXT, max_length=50)
    original_language: str = Field("ml", max_length=20)
    original_text: Optional[str] = None
    translated_text: Optional[str] = None
    priority: str = Field("medium", max_length=20)
    confirmed_location: Optional[Dict[str, Any]] = None
    location_sources: Optional[Dict[str, Any]] = None


class GrievanceClarificationRequest(BaseModel):
    response_text: str = Field(..., min_length=1)


class GrievanceVerificationRequest(BaseModel):
    verified_text: str = Field(..., min_length=1)
    attachment_id: Optional[str] = None


class GrievanceAuditLogResponse(BaseModel):
    id: str
    grievance_id: str
    actor_id: Optional[str] = None
    actor_role: str
    action_type: str
    previous_state: Optional[str] = None
    new_state: Optional[str] = None
    remarks: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class GrievanceIssueResponse(BaseModel):
    id: str
    grievance_id: str
    issue_number: int
    title: str
    description: Optional[str] = None
    category: str
    subcategory: Optional[str] = None
    severity: str
    priority: str
    status: str
    extracted_facts: Optional[Dict[str, Any]] = None
    interview_status: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class GrievanceInterviewQuestionResponse(BaseModel):
    id: str
    grievance_id: str
    issue_id: Optional[str] = None
    question: str
    question_type: str
    required: bool
    order_index: int
    status: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SingleInterviewResponseItem(BaseModel):
    question_id: str
    response_text: str = Field(..., min_length=1)


class GrievanceInterviewResponseRequest(BaseModel):
    responses: List[SingleInterviewResponseItem]


class GrievanceAIRunResponse(BaseModel):
    id: str
    grievance_id: str
    operation: str
    model: Optional[str] = None
    status: str
    input_summary: Optional[str] = None
    output_data: Optional[Dict[str, Any]] = None
    error_message: Optional[str] = None
    created_at: datetime
    completed_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


class GrievanceResponse(BaseModel):
    id: str
    grievance_number: str
    citizen_id: str
    title: Optional[str] = None
    description: Optional[str] = None
    intake_mode: str
    original_language: str
    original_text: Optional[str] = None
    translated_text: Optional[str] = None
    status: str
    priority: str
    severity: Optional[str] = None
    summary: Optional[str] = None
    ai_processing_status: Optional[str] = "pending"
    ai_processed_at: Optional[datetime] = None
    ai_model: Optional[str] = None
    ai_error_message: Optional[str] = None
    category: Optional[str] = None
    department_id: Optional[str] = None
    confirmed_location: Optional[Dict[str, Any]] = None
    location_sources: Optional[Dict[str, Any]] = None
    audit_logs: List[GrievanceAuditLogResponse] = []
    issues: List[GrievanceIssueResponse] = []
    interview_questions: List[GrievanceInterviewQuestionResponse] = []
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class GrievanceAttachmentResponse(BaseModel):
    id: str
    grievance_id: str
    attachment_type: str
    original_filename: str
    mime_type: str
    storage_path: str
    file_size_bytes: Optional[int] = None
    raw_extracted_text: Optional[str] = None
    extraction_status: str = "pending"
    extraction_confidence: Optional[float] = None
    extraction_engine: Optional[str] = None
    extraction_error: Optional[str] = None
    extracted_at: Optional[datetime] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
