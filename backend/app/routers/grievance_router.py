from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.database.session import get_db
from app.dependencies.auth_deps import get_current_user
from app.schemas.grievance_schema import (
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
