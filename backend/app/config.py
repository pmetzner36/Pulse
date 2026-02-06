import os
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # App
    app_name: str = "PULSE API"
    debug: bool = os.getenv("DEBUG", "true").lower() == "true"

    # Database — set DATABASE_URL env var in production (PostgreSQL)
    database_url: str = "sqlite+aiosqlite:///./pulse.db"

    # JWT — MUST set JWT_SECRET_KEY env var in production
    jwt_secret_key: str = "your-secret-key-change-in-production"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 30

    # Apple Sign In
    apple_team_id: str = ""
    apple_client_id: str = ""  # Your app's bundle ID
    apple_key_id: str = ""
    apple_private_key: str = ""

    # OpenAI (for content moderation)
    openai_api_key: str = ""  # Set this to enable AI moderation

    # CORS — set ALLOWED_ORIGINS env var in production (comma-separated)
    allowed_origins: str = "*"

    class Config:
        env_file = ".env"

    def validate_production(self):
        """Raise if critical settings are missing in production mode."""
        if not self.debug:
            if self.jwt_secret_key == "your-secret-key-change-in-production":
                raise RuntimeError("JWT_SECRET_KEY must be set in production")
            if "sqlite" in self.database_url:
                raise RuntimeError("Use PostgreSQL (DATABASE_URL) in production")


@lru_cache()
def get_settings() -> Settings:
    settings = Settings()
    settings.validate_production()
    return settings
