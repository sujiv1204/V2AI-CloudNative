from pydantic_settings import BaseSettings
from pathlib import Path


class Settings(BaseSettings):
    gcp_project_id: str
    gcs_bucket_name: str
    gcs_key_path: str
    firestore_db_name: str = "v2aidb"
    firestore_collection: str = "videos"
    upload_dir: str = "uploads"
    log_level: str = "INFO"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
