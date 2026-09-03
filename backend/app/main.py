from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.routers import auth_router, grievance_router, official_router

app = FastAPI(
    title=settings.PROJECT_NAME,
    description=(
        "JanMitra AI – AI-assisted Public Grievance Intelligence and "
        "Administrative Decision Support Platform API"
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
)

# CORS Middleware Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API Routers under /api/v1
app.include_router(auth_router, prefix=settings.API_V1_STR)
app.include_router(grievance_router, prefix=settings.API_V1_STR)
app.include_router(official_router, prefix=settings.API_V1_STR)


@app.on_event("startup")
async def on_startup():
    from app.database.session import init_db_schema
    await init_db_schema()


@app.get(
    f"{settings.API_V1_STR}/health",
    tags=["Health Check"],
    summary="Health check endpoint",
)
async def health_check():
    return {
        "status": "online",
        "platform": settings.PROJECT_NAME,
        "version": "1.0.0",
    }


@app.get("/", include_in_schema=False)
async def root():
    return {
        "message": f"Welcome to {settings.PROJECT_NAME} Backend API. Access documentation at /docs",
    }


if __name__ == "__main__":
    import os
    import uvicorn

    port = int(os.getenv("PORT", 8000))
    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=False)

