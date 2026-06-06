import logging

import httpx

from app.config import settings
from app.models.schemas import MetricsPayload

logger = logging.getLogger(__name__)


class HistoryService:
    """Persist downsampled metric snapshots to Supabase (PostgREST)."""

    def __init__(self) -> None:
        self._enabled = bool(
            settings.history_enabled
            and settings.supabase_url
            and settings.supabase_service_role_key
        )

    @property
    def enabled(self) -> bool:
        return self._enabled

    async def persist(self, payload: MetricsPayload) -> None:
        if not self._enabled:
            return

        running = [c for c in payload.containers if c.status == "running"]
        disk_max = max((d.percent for d in payload.host.disks), default=0.0)

        row = {
            "ts": payload.timestamp,
            "host_id": payload.host_id,
            "host_cpu": payload.host.cpu_percent if payload.host.available else None,
            "host_mem": payload.host.memory_percent if payload.host.available else None,
            "host_disk_max": disk_max,
            "containers_running": len(running),
            "containers_total": len(payload.containers),
            "ups_on_battery": payload.ups.on_battery,
            "battery": payload.ups.battery_charge_percent,
            "containers": [
                {
                    "name": c.name,
                    "status": c.status,
                    "cpu": c.cpu_percent,
                    "mem": c.memory_percent,
                }
                for c in payload.containers
            ],
        }

        url = f"{settings.supabase_url.rstrip('/')}/rest/v1/metrics_history"
        headers = {
            "apikey": settings.supabase_service_role_key,
            "Authorization": f"Bearer {settings.supabase_service_role_key}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal",
        }
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(url, headers=headers, json=row)
                if resp.status_code >= 400:
                    logger.warning(
                        "History insert failed (%s): %s", resp.status_code, resp.text
                    )
        except httpx.HTTPError as exc:
            logger.warning("History insert error: %s", exc)


history_service = HistoryService()
