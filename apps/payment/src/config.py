from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore"
    )

    service_name: str = "payment"
    app_env: str = "dev"
    app_port: int = 8082


settings = Settings()
