from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.core import security
from app.repositories.user_repository import UserRepository
from app.schemas.user_schema import Token, UserCreate, UserLogin, UserResponse


class AuthService:
    def __init__(self, db: AsyncSession):
        self.user_repo = UserRepository(db)

    async def register_user(self, user_in: UserCreate) -> UserResponse:
        existing_user = await self.user_repo.get_by_email(user_in.email)
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="An account with this email address already exists.",
            )

        hashed_password = security.get_password_hash(user_in.password)
        db_user = await self.user_repo.create(user_in, hashed_password)
        return UserResponse.model_validate(db_user)

    async def authenticate_user(self, credentials: UserLogin) -> Token:
        db_user = await self.user_repo.get_by_email(credentials.email)
        if not db_user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Email not registered. Please create an account.",
            )

        if not security.verify_password(credentials.password, db_user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect password. Please try again.",
            )

        if not db_user.is_active:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User account is inactive.",
            )

        access_token = security.create_access_token(subject=db_user.id)
        refresh_token = security.create_refresh_token(subject=db_user.id)
        user_response = UserResponse.model_validate(db_user)

        return Token(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer",
            user=user_response,
        )
