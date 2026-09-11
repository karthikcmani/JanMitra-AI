from typing import Any, Dict
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.session import get_db
from app.dependencies.auth_deps import get_current_user, get_current_official_or_admin
from app.schemas.user_schema import UserResponse
from app.services.jurisdiction_service import JurisdictionIntelligenceService

router = APIRouter(prefix="/jurisdiction", tags=["Jurisdiction Intelligence"])


class JurisdictionOverrideRequest(BaseModel):
    new_department: str
    new_authority: str
    remarks: str


@router.post(
    "/grievance/{grievance_id}/recommend",
    response_model=Dict[str, Any],
    status_code=status.HTTP_200_OK,
    summary="Get recommended administrative jurisdiction & competent authority for a grievance",
)
async def get_jurisdiction_recommendation(
    grievance_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user),
):
    service = JurisdictionIntelligenceService(db)
    try:
        return await service.recommend_jurisdiction(grievance_id)
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post(
    "/grievance/{grievance_id}/override",
    response_model=Dict[str, Any],
    status_code=status.HTTP_200_OK,
    summary="Override or confirm recommended jurisdiction (Admin/Official only)",
)
async def override_jurisdiction(
    grievance_id: str,
    override_in: JurisdictionOverrideRequest,
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_official_or_admin),
):
    service = JurisdictionIntelligenceService(db)
    try:
        return await service.override_recommendation(
            grievance_id=grievance_id,
            official_id=current_user.id,
            new_department=override_in.new_department,
            new_authority=override_in.new_authority,
            remarks=override_in.remarks,
        )
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
