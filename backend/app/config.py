from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # --- Storage (SQLite — no external DB container) ---
    db_path: str = "/data/rased.db"

    # --- Server identity (multi-server) ---
    host_id: str = "default"
    host_name: str = "My Server"
    # Externally reachable URL of THIS agent (so the dashboard can route here).
    public_base_url: str = ""

    # --- API server ---
    host: str = "0.0.0.0"
    port: int = 8002
    metrics_interval_seconds: int = 3

    # --- Auth (our own JWTs) ---
    jwt_secret: str = "change-me-rased-jwt-secret-min-32-characters"
    jwt_expiry_hours: int = 720  # 30 days
    # Key for encrypting stored AI api keys (any string; a Fernet key is derived).
    encryption_key: str = "change-me-rased-encryption-key"

    # --- Multi-agent ---
    # Shared secret for remote agents -> central /ingest. Same value on all nodes.
    agent_token: str = ""
    # Set on REMOTE agents to the central API URL (e.g. http://192.168.100.100:8002).
    # Leave empty on the CENTRAL node (it owns the DB + WebSocket).
    central_ingest_url: str = ""

    # --- NUT / UPS ---
    nut_host: str = "localhost"
    nut_port: int = 3493
    nut_ups_name: str = "ups"

    # --- CORS ---
    cors_origins: str = "http://localhost:8082,http://127.0.0.1:8082"

    # --- Alerting (POSTs JSON to any webhook: n8n / Slack / Discord auto-detected) ---
    alert_webhook_url: str = ""
    # Optional Telegram channel (bot token + chat id) in addition to the webhook.
    telegram_bot_token: str = ""
    telegram_chat_id: str = ""
    alert_cooldown_seconds: int = 600
    cpu_alert_percent: float = 90.0
    mem_alert_percent: float = 90.0
    disk_alert_percent: float = 85.0
    battery_alert_percent: float = 30.0
    proactive_triage_enabled: bool = True

    # --- Uptime / SSL checks: "Name|https://url, Name2|https://url2" ---
    uptime_checks: str = ""
    uptime_interval_seconds: int = 60
    uptime_timeout_seconds: float = 10.0
    ssl_alert_days: int = 14

    # --- History persistence (downsampled snapshots) ---
    history_enabled: bool = True
    history_interval_seconds: int = 60
    history_retain_days: int = 14
    alert_retain_days: int = 30
    maintenance_hour_utc: int = 4  # daily prune + WAL checkpoint
    agent_stale_factor: int = 4  # alert if a node hasn't reported in N*interval

    # --- Server-side AI (autonomous digest / proactive triage) ---
    ai_base_url: str = ""
    ai_model: str = ""
    ai_api_key: str = ""

    # --- Daily AI health digest ---
    digest_enabled: bool = False
    digest_hour_utc: int = 8

    # --- AI-assisted container deploy (admin reviews the plan, then installs) ---
    # Set ALLOW_CONTAINER_DEPLOY=false to disable the "Install" button entirely.
    allow_container_deploy: bool = True

    # --- AI cost guardrail: monthly token budget per user (0 = unlimited) ---
    ai_monthly_token_budget: int = 0

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def uptime_targets(self) -> list[tuple[str, str]]:
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

    @property
    def is_central(self) -> bool:
        """Central node owns the DB + WebSocket; remote agents POST to it."""
        return not self.central_ingest_url

    @property
    def insecure_secrets(self) -> list[str]:
        """Names of secrets still left at their shipped default (must be changed)."""
        bad = []
        if self.jwt_secret.startswith("change-me"):
            bad.append("JWT_SECRET")
        if self.encryption_key.startswith("change-me"):
            bad.append("ENCRYPTION_KEY")
        return bad

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
