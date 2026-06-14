import os
from typing import List, Optional
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    # App Settings
    APP_NAME: str = "Kolomoni Liveness Verification API"
    APP_ENV: str = "development"
    DEBUG: bool = True
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    
    # CORS Configurations
    ALLOWED_ORIGINS: List[str] = ["*"]
    
    # AWS Configuration
    # We make these optional so the app starts even without valid AWS credentials in Mock mode
    AWS_ACCESS_KEY_ID: Optional[str] = None
    AWS_SECRET_ACCESS_KEY: Optional[str] = None
    AWS_REGION: str = "us-east-1"
    
    # Liveness Settings
    LIVENESS_BUCKET: Optional[str] = None  # S3 bucket for storing audit images
    MOCK_AWS: bool = True  # Defaults to True for easy local setup without credentials
    LIVENESS_PROVIDER: str = "google_ml_kit"  # aws_rekognition, google_ml_kit, mock_provider
    LIVENESS_PASS_THRESHOLD: float = 95.0
    LIVENESS_MEDIUM_RISK_THRESHOLD: float = 80.0
    DEFAULT_LIVENESS_MODE: str = "PASSIVE_WITH_ACTIVE_FALLBACK"  # PASSIVE, ACTIVE, PASSIVE_WITH_ACTIVE_FALLBACK
    
    # Database Settings
    DATABASE_URL: str = "postgresql://postgres:postgres@db:5432/liveness"

    # Admin Settings
    ADMIN_EMAIL: str = "admin@kolomoni.com"
    ADMIN_PASSWORD: str = "AdminPassword123!"
    JWT_SECRET: str = "kolomoni_super_secret_jwt_key_987654321"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440 # 24 hours

    # AWS Cognito Settings (Option A Liveness Stream Authentication)
    COGNITO_POOL_ID: Optional[str] = None
    COGNITO_REGION: str = "us-east-1"
    
    
    # File storage configuration for audits when AWS is mocked
    MOCK_STORAGE_DIR: str = "mock_storage"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

settings = Settings()

# Create mock storage directory if it doesn't exist
if settings.MOCK_AWS and not os.path.exists(settings.MOCK_STORAGE_DIR):
    os.makedirs(settings.MOCK_STORAGE_DIR)
