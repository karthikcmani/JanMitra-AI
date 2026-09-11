from typing import Any, Dict, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.session import get_db
from app.dependencies.auth_deps import get_current_user
from app.schemas.user_schema import UserResponse
from app.services.legal_service import LegalIntelligenceService
from app.services.knowledge_service import KnowledgeBaseService

router = APIRouter(prefix="/legal", tags=["Legal Intelligence"])


@router.post(
    "/grievance/{grievance_id}/analyze",
    response_model=Dict[str, Any],
    status_code=status.HTTP_200_OK,
    summary="Trigger RAG Legal Intelligence analysis for a grievance",
)
async def analyze_legal_intelligence(
    grievance_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user),
):
    service = LegalIntelligenceService(db)
    try:
        return await service.analyze_legal_grounding(grievance_id)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND if "not found" in str(e).lower() else status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e),
        )


@router.get(
    "/search",
    response_model=List[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="Search official government document knowledge base",
)
async def search_knowledge_base(
    q: str,
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user),
):
    service = KnowledgeBaseService(db)
    return await service.search_relevant_chunks(q, top_k=5)
