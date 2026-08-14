from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.session import get_db
from app.dependencies.auth_deps import get_current_official_or_admin
from app.schemas.user_schema import UserResponse
from app.services.official_service import (
    OfficialActionRequest,
    OfficialGrievanceDetailResponse,
    OfficialService,
)

router = APIRouter(prefix="/official", tags=["Official Copilot"])


@router.get(
    "/grievances",
    response_model=List[OfficialGrievanceDetailResponse],
    status_code=status.HTTP_200_OK,
    summary="Retrieve all public grievances for official copilot review",
)
async def get_all_grievances_for_official(
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_official_or_admin),
):
    service = OfficialService(db)
    return await service.get_all_official_grievances()


@router.post(
    "/grievances/{grievance_id}/process",
    response_model=OfficialGrievanceDetailResponse,
    status_code=status.HTTP_200_OK,
    summary="Trigger document OCR text extraction and automated department routing analysis",
)
async def process_document_and_route_grievance(
    grievance_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_official_or_admin),
):
    service = OfficialService(db)
    return await service.process_document_and_route(
        grievance_id=grievance_id, official_id=current_user.id
    )


@router.post(
    "/grievances/{grievance_id}/action",
    response_model=OfficialGrievanceDetailResponse,
    status_code=status.HTTP_200_OK,
    summary="Submit official administrative action (Approve Route, Request Clarification, Resolve Issue)",
)
async def submit_official_action(
    grievance_id: str,
    action_in: OfficialActionRequest,
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_official_or_admin),
):
    service = OfficialService(db)
    return await service.update_official_action(
        grievance_id=grievance_id, official_id=current_user.id, action_in=action_in
    )

