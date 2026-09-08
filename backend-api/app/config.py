from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List
import os

class Settings(BaseSettings):
    PROJECT_NAME: str = "Gobi Backend API"
    VERSION: str = "0.1.0"
    ENV: str = "development"
    PORT: int = 8000
    
    # Database
    DATABASE_URL: str = "postgresql+asyncpg://gobi:gobi_password@localhost:5432/gobi_db"
    
    # JWT
    JWT_SECRET: str = "gobi-dev-secret-key-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRY_HOURS: int = 72
    
    # CORS
    CORS_ORIGINS: List[str] = ["*"]
    
    # OpenRouter
    OPENROUTER_API_KEY: str = ""
    OPENROUTER_BASE_URL: str = "https://openrouter.ai/api/v1"
    OPENROUTER_TEXT_MODEL: str = "meta-llama/llama-3.3-70b-instruct:free"
    OPENROUTER_VISION_MODEL: str = "google/gemini-2.0-flash-exp:free"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

settings = Settings()
