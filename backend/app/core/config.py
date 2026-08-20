import json
from pathlib import Path
from typing import List, Union
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "JanMitra AI"
    API_V1_STR: str = "/api/v1"

    POSTGRES_USER: str = "postgres"
    POSTGRES_PASSWORD: str = "postgres"
    POSTGRES_SERVER: str = "localhost"
    POSTGRES_PORT: int = 5432
    POSTGRES_DB: str = "janmitra_ai"


    DATABASE_URL: str = ""
    SYNC_DATABASE_URL: str = ""

    SECRET_KEY: str = (
        "janmitra_ai_super_secret_jwt_key_2026_change_in_production_12345"
    )
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440
    REFRESH_TOKEN_EXPIRE_MINUTES: int = 10080

    GEMINI_API_KEY: str = ""
    GOOGLE_API_KEY: str = ""

    CORS_ORIGINS: Union[List[str], str] = [
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:8000",
        "*",
    ]

    model_config = SettingsConfigDict(
        env_file=(
            str(Path(__file__).resolve().parent.parent.parent / "backend" / ".env"),
            str(Path(__file__).resolve().parent.parent.parent / ".env"),
            "backend/.env",
            ".env",
        ),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    def model_post_init(self, __context):
        if self.DATABASE_URL:
            if self.DATABASE_URL.startswith("postgres://"):
                self.DATABASE_URL = self.DATABASE_URL.replace("postgres://", "postgresql+asyncpg://", 1)
            elif self.DATABASE_URL.startswith("postgresql://") and not self.DATABASE_URL.startswith("postgresql+"):
                self.DATABASE_URL = self.DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)
        else:
            self.DATABASE_URL = f"postgresql+asyncpg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_SERVER}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"

        if self.SYNC_DATABASE_URL:
            if self.SYNC_DATABASE_URL.startswith("postgres://"):
                self.SYNC_DATABASE_URL = self.SYNC_DATABASE_URL.replace("postgres://", "postgresql+psycopg2://", 1)
            elif self.SYNC_DATABASE_URL.startswith("postgresql://") and not self.SYNC_DATABASE_URL.startswith("postgresql+"):
                self.SYNC_DATABASE_URL = self.SYNC_DATABASE_URL.replace("postgresql://", "postgresql+psycopg2://", 1)
        else:
            if self.DATABASE_URL and "asyncpg" in self.DATABASE_URL:
                self.SYNC_DATABASE_URL = self.DATABASE_URL.replace("postgresql+asyncpg://", "postgresql+psycopg2://", 1)
            else:
                self.SYNC_DATABASE_URL = f"postgresql+psycopg2://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_SERVER}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> List[str]:
        if isinstance(v, str):
            if v.startswith("[") and v.endswith("]"):
                return json.loads(v)
            return [i.strip() for i in v.split(",")]
        elif isinstance(v, list):
            return v
        raise ValueError(v)


settings = Settings()
