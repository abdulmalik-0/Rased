from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # --- Supabase (broadcast + history persistence) ---
    supabase_url: str = ""
    supabase_service_role_key: str = ""
    supabase_jwt_secret: str = ""
    supabase_broadcast_channel: str = "server-metrics"

    # --- Server identity (multi-server) ---
    host_id: str = "default"
    host_name: str = "My Server"
    # Externally reachable URL of THIS agent (so the dashboard can route
    # actions/logs/analyze to it). e.g. http://192.168.100.101:8002
    public_base_url: str = ""

    # --- API server ---
    host: str = "0.0.0.0"
    port: int = 8002
    metrics_interval_seconds: int = 3

    # --- NUT / UPS ---
    nut_host: str = "localhost"
    nut_port: int = 3493
    nut_ups_name: str = "ups"

    # --- CORS ---
    cors_origins: str = "http://localhost:8082,http://127.0.0.1:8082"

    # --- Alerting (routes to n8n / Telegram / any webhook) ---
    alert_webhook_url: str = ""
    alert_cooldown_seconds: int = 600
    cpu_alert_percent: float = 90.0
    mem_alert_percent: float = 90.0
    disk_alert_percent: float = 85.0
    battery_alert_percent: float = 30.0
    proactive_triage_enabled: bool = True

    # --- Uptime / SSL checks ---
    # Format: "Name|https://url, Name2|https://url2" (name optional: "https://url")
    uptime_checks: str = ""
    uptime_interval_seconds: int = 60
    uptime_timeout_seconds: float = 10.0
    ssl_alert_days: int = 14

    # --- History persistence (downsampled snapshots to Supabase) ---
    history_enabled: bool = True
    history_interval_seconds: int = 60

    # --- Server-side AI (autonomous digest / proactive triage) ---
    # Leave empty to disable autonomous AI features; on-demand /analyze uses
    # the per-user config sent from the frontend instead.
    ai_base_url: str = ""
    ai_model: str = ""
    ai_api_key: str = ""

    # --- Daily AI health digest ---
    digest_enabled: bool = False
    digest_hour_utc: int = 8

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def uptime_targets(self) -> list[tuple[str, str]]:
        """Parse uptime_checks into a list of (name, url) tuples."""
        targets: list[tuple[str, str]] = []
        for raw in self.uptime_checks.split(","):
            entry = raw.strip()
            if not entry:
                continue
            if "|" in entry:
                name, _, url = entry.partition("|")
                name, url = name.strip(), url.strip()
            else:
                url = entry
                name = entry.replace("https://", "").replace("http://", "").rstrip("/")
            if url:
                targets.append((name or url, url))
        return targets

    @property
    def ai_configured(self) -> bool:
        return bool(self.ai_base_url and self.ai_model)

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
