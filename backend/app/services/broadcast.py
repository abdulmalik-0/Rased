import asyncio
import json
import logging

import httpx

from app.config import settings
from app.models.schemas import MetricsPayload

logger = logging.getLogger(__name__)


class SupabaseBroadcastService:
    """Push metrics to Supabase Realtime Broadcast via REST API."""

    def __init__(self) -> None:
        self._enabled = bool(settings.supabase_url and settings.supabase_service_role_key)

    async def broadcast_metrics(self, payload: MetricsPayload) -> None:
        if not self._enabled:
            logger.debug("Supabase broadcast disabled (missing credentials)")
            return

        url = f"{settings.supabase_url.rstrip('/')}/realtime/v1/api/broadcast"
        headers = {
            "apikey": settings.supabase_service_role_key,
            "Authorization": f"Bearer {settings.supabase_service_role_key}",
            "Content-Type": "application/json",
        }
        body = {
            "messages": [
                {
                    "topic": settings.supabase_broadcast_channel,
                    "event": "metrics",
                    "payload": json.loads(payload.model_dump_json()),
                }
            ]
        }

        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.post(url, headers=headers, json=body)
                if response.status_code >= 400:
                    logger.warning(
                        "Broadcast failed (%s): %s",
                        response.status_code,
                        response.text,
                    )
        except httpx.HTTPError as exc:
            logger.warning("Broadcast HTTP error: %s", exc)


broadcast_service = SupabaseBroadcastService()


async def metrics_collector_loop(
    docker_svc,
    nut_svc,
    broadcast_svc,
    interval: int,
) -> None:
    while True:
        ups = nut_svc.get_status()
        metrics = docker_svc.collect_metrics(ups)
        await broadcast_svc.broadcast_metrics(metrics)
        await asyncio.sleep(interval)
