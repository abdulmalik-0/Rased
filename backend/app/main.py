import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app import db
from app.config import settings
from app.services import app_config
from app.models.schemas import HostStats, MetricsPayload
from app.routers import (
    actions,
    analyze,
    ask,
    auth,
    data,
    deploy,
    ingest,
    logs,
    setup,
    ws,
)
from app.services.collector import build_payload, collector_loop
from app.services.host_service import host_service
from app.services.realtime import realtime

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    insecure = settings.insecure_secrets
    if insecure:
        raise RuntimeError(
            f"Refusing to start: {', '.join(insecure)} still use the shipped default. "
            "Set strong random values in .env (scripts/install.sh generates them)."
        )
    if settings.is_central:
        await db.init_db()
        await app_config.refresh()
    task = asyncio.create_task(collector_loop())
    logger.info(
        "Rased agent started (host=%s, central=%s)",
        settings.host_name,
        settings.is_central,
    )
    yield
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass
    if settings.is_central:
        await db.close_db()


app = FastAPI(
    title="Rased — Server Dashboard Agent",
    description="Docker + host metrics, AI log analysis, auth, realtime, history "
    "(SQLite, no external DB).",
    version="3.0.0",
    lifespan=lifespan,
)

allowed_origins = settings.cors_origin_list or [
    "http://localhost:8082",
    "http://127.0.0.1:8082",
]
if not settings.cors_origin_list:
    logger.warning("CORS_ORIGINS not set; defaulting to localhost only")

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Every node exposes these (verified via shared JWT secret).
app.include_router(logs.router)
app.include_router(analyze.router)
app.include_router(actions.router)
app.include_router(ask.router)
app.include_router(deploy.router)

# Central node owns auth, data, ingest, setup and the realtime WebSocket.
if settings.is_central:
    app.include_router(auth.router)
    app.include_router(data.router)
    app.include_router(ingest.router)
    app.include_router(setup.router)
    app.include_router(ws.router)


@app.get("/health")
async def health() -> dict:
    return {
        "status": "ok",
        "host_id": settings.host_id,
        "host_name": settings.host_name,
        "central": settings.is_central,
    }


@app.get("/metrics", response_model=MetricsPayload)
async def get_current_metrics() -> MetricsPayload:
    return await build_payload()


@app.get("/host", response_model=HostStats)
async def get_host() -> HostStats:
    return host_service.get_stats()


@app.get("/metrics/all", response_model=list[MetricsPayload])
async def get_all_metrics() -> list[MetricsPayload]:
    """All hosts (central): from the realtime cache. Remote: just itself."""
    if settings.is_central:
        return list(realtime.latest.values())
    return [await build_payload()]
