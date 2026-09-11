from app.routers.auth_router import router as auth_router
from app.routers.duplicate_router import router as duplicate_router
from app.routers.grievance_router import router as grievance_router
from app.routers.jurisdiction_router import router as jurisdiction_router
from app.routers.legal_router import router as legal_router
from app.routers.notification_router import router as notification_router
from app.routers.official_router import router as official_router

__all__ = [
    "auth_router",
    "grievance_router",
    "official_router",
    "legal_router",
    "jurisdiction_router",
    "duplicate_router",
    "notification_router",
]

