from typing import List, Optional
from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.session import get_db
from app.dependencies.auth_deps import get_current_official_or_admin
from app.schemas.user_schema import UserResponse
from app.services.official_service import (
    DepartmentWorkloadResponse,
    OfficialActionRequest,
    OfficialDashboardSummaryResponse,
    OfficialGrievanceDetailResponse,
    OfficialService,
)

router = APIRouter(prefix="/official", tags=["Official Copilot"])


@router.get(
    "/dashboard/summary",
    response_model=OfficialDashboardSummaryResponse,
    status_code=status.HTTP_200_OK,
    summary="Retrieve real-time administrative dashboard summary metrics",
)
async def get_official_dashboard_summary(
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_official_or_admin),
):
    service = OfficialService(db)
    return await service.get_dashboard_summary()


@router.get(
    "/grievances/search",
    response_model=List[OfficialGrievanceDetailResponse],
    status_code=status.HTTP_200_OK,
    summary="Server-side search and filtering for official grievances",
)
async def search_grievances_for_official(
    query: Optional[str] = None,
    status: Optional[str] = None,
    priority: Optional[str] = None,
    department_id: Optional[str] = None,
    category: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_official_or_admin),
):
    service = OfficialService(db)
    return await service.search_official_grievances(
        query=query,
        status=status,
        priority=priority,
        department_id=department_id,
        category=category,
    )


@router.get(
    "/grievances/attention-queue",
    response_model=List[OfficialGrievanceDetailResponse],
    status_code=status.HTTP_200_OK,
    summary="Retrieve grievances ordered by attention priority",
)
async def get_attention_queue_for_official(
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_official_or_admin),
):
    service = OfficialService(db)
    return await service.get_attention_queue()


@router.get(
    "/admin/department-workload",
    response_model=List[DepartmentWorkloadResponse],
    status_code=status.HTTP_200_OK,
    summary="Retrieve departmental workload distribution for admin overview",
)
async def get_admin_department_workload(
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_official_or_admin),
):
    service = OfficialService(db)
    return await service.get_department_workload()


@router.get(
    "/admin/officials",
    response_model=List[dict],
    status_code=status.HTTP_200_OK,
    summary="Retrieve roster of registered government officials for admin management",
)
async def get_admin_official_users(
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_official_or_admin),
):
    service = OfficialService(db)
    return await service.get_all_official_users()


@router.put(
    "/admin/users/{user_id}",
    response_model=dict,
    status_code=status.HTTP_200_OK,
    summary="Update official user status (active/inactive) or department assignment",
)
async def update_admin_official_user(
    user_id: str,
    payload: dict,
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_official_or_admin),
):
    service = OfficialService(db)
    return await service.update_official_user_status(
        user_id=user_id,
        is_active=payload.get("is_active"),
        department_id=payload.get("department_id"),
    )



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

