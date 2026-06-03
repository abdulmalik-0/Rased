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


class UpsStatus(BaseModel):
    connected: bool = False
    on_battery: bool = False
    battery_charge_percent: float | None = None
    status: str = "unknown"
    error: str | None = None


class MetricsPayload(BaseModel):
    timestamp: str
    containers: list[ContainerMetrics]
    ups: UpsStatus


class AIProviderConfig(BaseModel):
    provider_type: str = Field(..., description="ollama | lm_studio | cloud | custom")
    base_url: str
    model_name: str
    api_key: str = ""


class AnalyzeRequest(BaseModel):
    container_id: str
    ai_config: AIProviderConfig
    custom_prompt: str | None = None


class AnalyzeResponse(BaseModel):
    analysis: str
    sanitized_log_preview: str
    model_used: str


class LogsResponse(BaseModel):
    container_id: str
    lines: list[str]
    sanitized_lines: list[str]
