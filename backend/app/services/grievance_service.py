import time
from typing import List
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.repositories.grievance_repository import GrievanceRepository
from app.schemas.grievance_schema import (
    GrievanceDraftCreate,
    GrievanceResponse,
)


class GrievanceService:
    def __init__(self, db: AsyncSession):
        self.repo = GrievanceRepository(db)

    @staticmethod
    def _generate_grievance_number() -> str:
        timestamp_ms = int(time.time() * 1000) % 100000000
        return f"JM-2026-{timestamp_ms:08d}"

    async def create_draft(
        self, citizen_id: str, draft_in: GrievanceDraftCreate
    ) -> GrievanceResponse:
        grievance_no = self._generate_grievance_number()
        db_grievance = await self.repo.create_grievance(
            citizen_id=citizen_id,
            draft_in=draft_in,
            grievance_number=grievance_no,
        )
        return GrievanceResponse.model_validate(db_grievance)

    async def get_citizen_grievances(
        self, citizen_id: str
    ) -> List[GrievanceResponse]:
        grievances = await self.repo.get_all_by_citizen_id(citizen_id)
        return [GrievanceResponse.model_validate(g) for g in grievances]

    async def get_grievance_by_id(
        self, grievance_id: str, citizen_id: str
    ) -> GrievanceResponse:
        grievance = await self.repo.get_user_grievance(grievance_id, citizen_id)
        if not grievance:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Grievance not found.",
            )
        return GrievanceResponse.model_validate(grievance)
