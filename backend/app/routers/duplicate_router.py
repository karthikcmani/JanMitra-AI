from typing import Any, Dict, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.session import get_db
from app.dependencies.auth_deps import get_current_user
from app.schemas.user_schema import UserResponse
from app.services.duplicate_service import DuplicateDetectionService

router = APIRouter(prefix="/duplicates", tags=["Duplicate Detection"])


@router.get(
    "/grievance/{grievance_id}",
    response_model=List[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="Detect potential duplicate or similar grievances",
)
async def detect_duplicate_grievances(
    grievance_id: str,
    threshold: float = 0.60,
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user),
):
    service = DuplicateDetectionService(db)
    try:
        return await service.detect_duplicates(grievance_id, similarity_threshold=threshold)
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
