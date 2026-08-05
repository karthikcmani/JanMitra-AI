from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.database.session import get_db
from app.dependencies.auth_deps import get_current_user
from app.schemas.user_schema import (
    MsgResponse,
    Token,
    UserCreate,
    UserLogin,
    UserResponse,
)
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post(
    "/register",
    response_model=dict,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new citizen user",
)
async def register(
    user_in: UserCreate,
    db: AsyncSession = Depends(get_db),
):
    service = AuthService(db)
    user = await service.register_user(user_in)
    return {"user": user}


@router.post(
    "/login",
    response_model=Token,
    status_code=status.HTTP_200_OK,
    summary="Authenticate user and issue JWT access token",
)
async def login(
    credentials: UserLogin,
    db: AsyncSession = Depends(get_db),
):
    service = AuthService(db)
    return await service.authenticate_user(credentials)


@router.get(
    "/me",
    response_model=UserResponse,
    status_code=status.HTTP_200_OK,
    summary="Retrieve authenticated user profile",
)
async def get_me(
    current_user: UserResponse = Depends(get_current_user),
):
    return current_user


@router.post(
    "/logout",
    response_model=MsgResponse,
    status_code=status.HTTP_200_OK,
    summary="Stateless JWT Logout",
)
async def logout(
    current_user: UserResponse = Depends(get_current_user),
):
    """
    Stateless JWT Logout Strategy:
    In JWT authentication, session state is maintained securely on the client side.
    Executing logout confirms token validity and instructs the client app (Flutter/Web)
    to erase access and refresh tokens from Secure Storage.
    """
    return MsgResponse(
        message="Logout successful. Please clear tokens from secure client storage."
    )
