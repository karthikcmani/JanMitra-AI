import logging
from typing import Any, Dict, List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.grievance_model import UserNotification

logger = logging.getLogger(__name__)


class NotificationService:
    """In-App User Notification Service for Citizens and Officials."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_notification(
        self,
        user_id: str,
        title: str,
        message: str,
        grievance_id: Optional[str] = None,
        notification_type: str = "STATUS_CHANGE",
    ) -> UserNotification:
        """Creates a persistent in-app notification record."""
        notification = UserNotification(
            user_id=user_id,
            title=title,
            message=message,
            grievance_id=grievance_id,
            notification_type=notification_type,
            is_read=False,
        )
        self.db.add(notification)
        await self.db.commit()
        await self.db.refresh(notification)
        return notification

    async def get_user_notifications(self, user_id: str, unread_only: bool = False) -> List[UserNotification]:
        """Retrieves all notifications for a specific user."""
        query = select(UserNotification).where(UserNotification.user_id == user_id)
        if unread_only:
            query = query.where(UserNotification.is_read == False)
        query = query.order_by(UserNotification.created_at.desc())

        res = await self.db.execute(query)
        return res.scalars().all()

    async def mark_as_read(self, notification_id: str, user_id: str) -> bool:
        """Marks a notification as read."""
        res = await self.db.execute(
            select(UserNotification).where(
                UserNotification.id == notification_id, UserNotification.user_id == user_id
            )
        )
        notif = res.scalar_one_or_none()
        if notif:
            notif.is_read = True
            await self.db.commit()
            return True
        return False
