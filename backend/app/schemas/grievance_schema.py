from datetime import datetime
from typing import Any, Dict, Optional
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
    confirmed_location: Optional[Dict[str, Any]] = None
    location_sources: Optional[Dict[str, Any]] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


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


class GrievanceAttachmentResponse(BaseModel):
    id: str
    grievance_id: str
    attachment_type: str
    original_filename: str
    mime_type: str
    storage_path: str
    file_size_bytes: Optional[int] = None
    raw_extracted_text: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
