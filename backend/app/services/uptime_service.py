import asyncio
import logging
import socket
import ssl
import time
from datetime import datetime, timezone
from urllib.parse import urlparse

import httpx

from app.config import settings
from app.models.schemas import UptimeResult

logger = logging.getLogger(__name__)


def _cert_expiry_days(host: str, port: int = 443) -> int | None:
    """Return days until the TLS certificate for host expires (or None)."""
    try:
        ctx = ssl.create_default_context()
        with socket.create_connection((host, port), timeout=5.0) as sock:
            with ctx.wrap_socket(sock, server_hostname=host) as ssock:
                cert = ssock.getpeercert()
        not_after = cert.get("notAfter")
        if not not_after:
            return None
        expires = datetime.strptime(not_after, "%b %d %H:%M:%S %Y %Z").replace(
            tzinfo=timezone.utc
        )
        return (expires - datetime.now(timezone.utc)).days
    except Exception as exc:  # noqa: BLE001 - best-effort, never fatal
        logger.debug("Cert check failed for %s: %s", host, exc)
        return None


class UptimeService:
    """Periodic HTTP availability + TLS expiry checks for configured URLs."""

    def __init__(self) -> None:
        self.latest: list[UptimeResult] = []

    async def _check_one(self, name: str, url: str) -> UptimeResult:
        parsed = urlparse(url)
        start = time.monotonic()
        try:
            async with httpx.AsyncClient(
                timeout=settings.uptime_timeout_seconds, follow_redirects=True
            ) as client:
                resp = await client.get(url)
            latency = round((time.monotonic() - start) * 1000, 1)

            cert_days = None
            if parsed.scheme == "https" and parsed.hostname:
                port = parsed.port or 443
                cert_days = await asyncio.to_thread(
                    _cert_expiry_days, parsed.hostname, port
                )

            return UptimeResult(
                name=name,
                url=url,
                up=resp.status_code < 400,
                status_code=resp.status_code,
                latency_ms=latency,
                cert_expiry_days=cert_days,
            )
        except Exception as exc:  # noqa: BLE001 - report as down, never raise
            return UptimeResult(name=name, url=url, up=False, error=str(exc))

    async def refresh(self) -> list[UptimeResult]:
        targets = settings.uptime_targets
        if not targets:
            self.latest = []
            return self.latest
        results = await asyncio.gather(
            *(self._check_one(name, url) for name, url in targets)
        )
        self.latest = list(results)
        return self.latest


uptime_service = UptimeService()
