import logging
from datetime import datetime, timezone

import httpx

from app.config import settings

logger = logging.getLogger(__name__)


class DeviceService:
    """Self-register this agent in the Supabase `devices` table so the dashboard
    can show one tab per machine and route actions to the right agent."""

    def __init__(self) -> None:
        self._enabled = bool(
            settings.supabase_url and settings.supabase_service_role_key
        )

    async def register(self) -> None:
        if not self._enabled:
            return
        url = f"{settings.supabase_url.rstrip('/')}/rest/v1/devices"
        headers = {
            "apikey": settings.supabase_service_role_key,
            "Authorization": f"Bearer {settings.supabase_service_role_key}",
            "Content-Type": "application/json",
            # Upsert on the primary key (host_id).
            "Prefer": "resolution=merge-duplicates,return=minimal",
        }
        row = {
            "host_id": settings.host_id,
            "host_name": settings.host_name,
            "api_url": settings.public_base_url,
            "last_seen": datetime.now(timezone.utc).isoformat(),
        }
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(url, headers=headers, json=row)
                if resp.status_code >= 400:
                    logger.warning(
                        "Device register failed (%s): %s",
                        resp.status_code,
                        resp.text,
                    )
        except httpx.HTTPError as exc:
            logger.warning("Device register error: %s", exc)


device_service = DeviceService()
