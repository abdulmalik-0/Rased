from pydantic import BaseModel, Field


class ContainerMetrics(BaseModel):
    id: str
    name: str
    status: str
    image: str
    cpu_percent: float = 0.0
    memory_usage_mb: float = 0.0
    memory_limit_mb: float = 0.0
    memory_percent: float = 0.0
    restart_count: int = 0
    ports: list[str] = Field(default_factory=list)


class DiskUsage(BaseModel):
    mount: str
    used_gb: float = 0.0
    total_gb: float = 0.0
    percent: float = 0.0


class Temp(BaseModel):
    label: str
    current: float
    high: float | None = None


class HostStats(BaseModel):
    available: bool = False
    cpu_percent: float = 0.0
    cpu_cores: int = 0
    memory_used_mb: float = 0.0
    memory_total_mb: float = 0.0
    memory_percent: float = 0.0
    disks: list[DiskUsage] = Field(default_factory=list)
    temperatures: list[Temp] = Field(default_factory=list)
    load_avg_1m: float | None = None
    uptime_seconds: float | None = None
    error: str | None = None


class UpsStatus(BaseModel):
    connected: bool = False
    on_battery: bool = False
    battery_charge_percent: float | None = None
    status: str = "unknown"
    error: str | None = None


class UptimeResult(BaseModel):
    name: str
    url: str
    up: bool = False
    status_code: int | None = None
    latency_ms: float | None = None
    cert_expiry_days: int | None = None
    error: str | None = None


class Alert(BaseModel):
    level: str = "warning"  # info | warning | critical
    kind: str  # cpu | memory | disk | container_down | ups | uptime | ssl | anomaly
    target: str
    message: str
    value: float | None = None
    timestamp: str


class MetricsPayload(BaseModel):
    timestamp: str
    host_id: str = "default"
    host_name: str = "My Server"
    containers: list[ContainerMetrics]
    ups: UpsStatus
    host: HostStats = Field(default_factory=HostStats)
    uptime: list[UptimeResult] = Field(default_factory=list)
    alerts: list[Alert] = Field(default_factory=list)


class AIProviderConfig(BaseModel):
    provider_type: str = Field(..., description="ollama | lm_studio | cloud | custom")
    base_url: str
    model_name: str
    api_key: str = ""


class AnalyzeRequest(BaseModel):
    container_id: str
    ai_config: AIProviderConfig
    custom_prompt: str | None = None
    tail: int = 100
    lang: str = "en"


class AnalyzeResponse(BaseModel):
    analysis: str
    sanitized_log_preview: str
    model_used: str


class AskRequest(BaseModel):
    question: str
    ai_config: AIProviderConfig
    container_id: str | None = None
    include_logs: bool = True
    history: list[dict] = Field(default_factory=list)
    lang: str = "en"


class AskResponse(BaseModel):
    answer: str
    model_used: str


class DeploySuggestRequest(BaseModel):
    description: str
    ai_config: AIProviderConfig
    lang: str = "en"


class DeploySuggestResponse(BaseModel):
    suggestion: str
    model_used: str


class DeployPlanRequest(BaseModel):
    description: str
    ai_config: AIProviderConfig
    lang: str = "en"


class PortMap(BaseModel):
    host: int
    container: int


class VolumeMap(BaseModel):
    host: str
    container: str


class DeployPlan(BaseModel):
    image: str
    name: str = ""
    ports: list[PortMap] = Field(default_factory=list)
    volumes: list[VolumeMap] = Field(default_factory=list)
    env: dict[str, str] = Field(default_factory=dict)
    restart: str = "unless-stopped"
    notes: str = ""


class DeployRunResponse(BaseModel):
    id: str
    name: str
    status: str


class ContainerActionRequest(BaseModel):
    action: str = Field(..., description="restart | stop | start")


class ContainerActionResponse(BaseModel):
    container_id: str
    action: str
    status: str
    message: str


class LogsResponse(BaseModel):
    container_id: str
    lines: list[str]
    sanitized_lines: list[str]


class AuthRequest(BaseModel):
    email: str
    password: str


class AuthResponse(BaseModel):
    token: str
    email: str
    role: str


class RoleUpdate(BaseModel):
    role: str


class UserUpdate(BaseModel):
    role: str | None = None
    approved: bool | None = None


class RegisterResponse(BaseModel):
    pending: bool = False
    token: str | None = None
    email: str
    role: str


class ServerConfig(BaseModel):
    nut_host: str = ""
    nut_ups_name: str = ""


class DeviceOverride(BaseModel):
    display_name: str | None = None
    nut_host: str | None = None
    nut_ups_name: str | None = None


class LinkUpsert(BaseModel):
    host_id: str
    name: str
    url: str = ""
    label: str = ""


class ChatUpsert(BaseModel):
    id: str | None = None
    host_id: str = "default"
    title: str = "Chat"
    messages: list[dict] = Field(default_factory=list)
