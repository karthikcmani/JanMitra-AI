from typing import Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.user_model import User
from app.schemas.user_schema import UserCreate


class UserRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, user_id: str) -> Optional[User]:
        result = await self.db.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()

    async def get_by_email(self, email: str) -> Optional[User]:
        result = await self.db.execute(
            select(User).where(User.email == email.lower())
        )
        return result.scalar_one_or_none()

    async def create(self, user_in: UserCreate, password_hash: str) -> User:
        db_user = User(
            full_name=user_in.full_name,
            email=user_in.email.lower(),
            phone=user_in.phone,
            password_hash=password_hash,
            role=user_in.role,
            is_active=True,
        )
        self.db.add(db_user)
        await self.db.flush()
        await self.db.refresh(db_user)
        return db_user
