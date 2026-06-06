import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.models.schemas import Alert, HostStats, MetricsPayload, UptimeResult
from app.routers import actions, analyze, ask, logs
from app.services.alert_service import alert_service
from app.services.collector import build_payload, collector_loop
from app.services.host_service import host_service
from app.services.uptime_service import uptime_service

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    task = asyncio.create_task(collector_loop())
    logger.info(
        "Metrics collector started (interval=%ss, host=%s)",
        settings.metrics_interval_seconds,
        settings.host_name,
    )
    yield
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass


app = FastAPI(
    title="Rased — AI Server Dashboard Agent",
    description="Docker + host metrics collector, log fetcher, AI log analyzer, "
    "alerting, uptime checks, and history.",
    version="2.0.0",
    lifespan=lifespan,
)

# CORS: never silently fall back to a wildcard. If unset, keep a safe localhost
# default and warn so misconfiguration is visible in production.
allowed_origins = settings.cors_origin_list
if not allowed_origins:
    allowed_origins = ["http://localhost:8082", "http://127.0.0.1:8082"]
    logger.warning("CORS_ORIGINS not set; defaulting to localhost only: %s", allowed_origins)

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(logs.router)
app.include_router(analyze.router)
app.include_router(actions.router)
app.include_router(ask.router)


@app.get("/health")
async def health() -> dict:
    return {
        "status": "ok",
        "host_id": settings.host_id,
        "host_name": settings.host_name,
    }


@app.get("/metrics", response_model=MetricsPayload)
async def get_current_metrics() -> MetricsPayload:
    """Fallback REST endpoint when Realtime is unavailable."""
    return await build_payload()


@app.get("/host", response_model=HostStats)
async def get_host() -> HostStats:
    return host_service.get_stats()


@app.get("/uptime", response_model=list[UptimeResult])
async def get_uptime() -> list[UptimeResult]:
    if not uptime_service.latest and settings.uptime_targets:
        await uptime_service.refresh()
    return uptime_service.latest


@app.get("/alerts", response_model=list[Alert])
async def get_alerts() -> list[Alert]:
    return alert_service.recent[-50:]
