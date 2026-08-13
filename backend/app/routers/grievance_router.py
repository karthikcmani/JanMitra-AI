from typing import List
from fastapi import APIRouter, Depends, File, Form, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession
from app.database.session import get_db
from app.dependencies.auth_deps import get_current_user
from app.models.grievance_model import AttachmentType
from app.schemas.grievance_schema import (
    GrievanceAttachmentResponse,
    GrievanceDraftCreate,
    GrievanceResponse,
)
from app.schemas.user_schema import UserResponse
from app.services.grievance_service import GrievanceService

router = APIRouter(prefix="/grievances", tags=["Grievances"])


@router.post(
    "/intake/draft",
    response_model=GrievanceResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Initialize a new grievance draft for authenticated citizen",
)
async def create_grievance_draft(
    draft_in: GrievanceDraftCreate,
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user),
):
    service = GrievanceService(db)
    return await service.create_draft(
        citizen_id=current_user.id, draft_in=draft_in
    )


@router.get(
    "/my",
    response_model=List[GrievanceResponse],
    status_code=status.HTTP_200_OK,
    summary="Retrieve all grievances belonging to authenticated citizen",
)
async def get_my_grievances(
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user),
):
    service = GrievanceService(db)
    return await service.get_citizen_grievances(citizen_id=current_user.id)


@router.get(
    "/{grievance_id}",
    response_model=GrievanceResponse,
    status_code=status.HTTP_200_OK,
    summary="Retrieve one grievance belonging to authenticated citizen",
)
async def get_grievance_detail(
    grievance_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user),
):
    service = GrievanceService(db)
    return await service.get_grievance_by_id(
        grievance_id=grievance_id, citizen_id=current_user.id
    )


@router.post(
    "/{grievance_id}/attachments",
    response_model=GrievanceAttachmentResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Upload an intake file attachment for a grievance (JPEG, PNG, WEBP, PDF)",
)
async def upload_grievance_attachment(
    grievance_id: str,
    file: UploadFile = File(...),
    attachment_type: str = Form(AttachmentType.HANDWRITTEN_PETITION),
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user),
):
    service = GrievanceService(db)
    return await service.upload_attachment(
        citizen_id=current_user.id,
        grievance_id=grievance_id,
        file=file,
        attachment_type=attachment_type,
    )


@router.get(
    "/{grievance_id}/attachments/{attachment_id}",
    response_class=FileResponse,
    status_code=status.HTTP_200_OK,
    summary="Download/retrieve an uploaded attachment file securely",
)
async def download_grievance_attachment(
    grievance_id: str,
    attachment_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user),
):
    service = GrievanceService(db)
    abs_path, mime_type, original_filename = await service.get_attachment_file(
        citizen_id=current_user.id,
        grievance_id=grievance_id,
        attachment_id=attachment_id,
    )
    return FileResponse(
        path=abs_path,
        media_type=mime_type,
        filename=original_filename,
    )
