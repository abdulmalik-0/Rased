from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    supabase_url: str = ""
    supabase_service_role_key: str = ""
    supabase_broadcast_channel: str = "server-metrics"

    host: str = "0.0.0.0"
    port: int = 8002
    metrics_interval_seconds: int = 3

    nut_host: str = "localhost"
    nut_port: int = 3493
    nut_ups_name: str = "ups"

    cors_origins: str = "http://localhost:8082,http://127.0.0.1:8082"

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
