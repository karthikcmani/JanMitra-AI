from typing import Any, Dict, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database.session import get_db
from app.dependencies.auth_deps import get_current_user
from app.schemas.user_schema import UserResponse
from app.services.notification_service import NotificationService

router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get(
    "/my",
    response_model=List[Dict[str, Any]],
    status_code=status.HTTP_200_OK,
    summary="Retrieve all in-app notifications for authenticated user",
)
async def get_my_notifications(
    unread_only: bool = False,
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user),
):
    service = NotificationService(db)
    notifs = await service.get_user_notifications(user_id=current_user.id, unread_only=unread_only)
    return [
        {
            "id": n.id,
            "title": n.title,
            "message": n.message,
            "grievance_id": n.grievance_id,
            "notification_type": n.notification_type,
            "is_read": n.is_read,
            "created_at": str(n.created_at),
        }
        for n in notifs
    ]


@router.post(
    "/{notification_id}/read",
    response_model=Dict[str, Any],
    status_code=status.HTTP_200_OK,
    summary="Mark notification as read",
)
async def mark_notification_read(
    notification_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user),
):
    service = NotificationService(db)
    success = await service.mark_as_read(notification_id, current_user.id)
    if not success:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found.")
    return {"status": "success", "message": "Notification marked as read."}
