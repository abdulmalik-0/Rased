import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.models.schemas import MetricsPayload
from app.routers import analyze, logs
from app.services.broadcast import broadcast_service, metrics_collector_loop
from app.services.docker_service import docker_service
from app.services.nut_service import nut_service

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    task = asyncio.create_task(
        metrics_collector_loop(
            docker_service,
            nut_service,
            broadcast_service,
            settings.metrics_interval_seconds,
        )
    )
    logger.info(
        "Metrics collector started (interval=%ss)",
        settings.metrics_interval_seconds,
    )
    yield
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass


app = FastAPI(
    title="AI Server Dashboard Agent",
    description="Docker metrics collector, log fetcher, and AI log analyzer",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list or ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(logs.router)
app.include_router(analyze.router)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@app.get("/metrics", response_model=MetricsPayload)
async def get_current_metrics() -> MetricsPayload:
    """Fallback REST endpoint when Realtime is unavailable."""
    ups = nut_service.get_status()
    return docker_service.collect_metrics(ups)
