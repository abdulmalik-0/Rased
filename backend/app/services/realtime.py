import asyncio
import logging

from fastapi import WebSocket

from app.models.schemas import MetricsPayload

logger = logging.getLogger(__name__)


class RealtimeManager:
    """Holds the latest payload per host and fans out to WebSocket clients."""

    def __init__(self) -> None:
        self._clients: set[WebSocket] = set()
        self.latest: dict[str, MetricsPayload] = {}
        self._lock = asyncio.Lock()

    async def connect(self, ws: WebSocket) -> None:
        await ws.accept()
        async with self._lock:
            self._clients.add(ws)
        # Send the current snapshot of every known host.
        for payload in list(self.latest.values()):
            try:
                await ws.send_text(payload.model_dump_json())
            except Exception:  # noqa: BLE001
                break

    async def disconnect(self, ws: WebSocket) -> None:
        async with self._lock:
            self._clients.discard(ws)

    async def publish(self, payload: MetricsPayload) -> None:
        self.latest[payload.host_id] = payload
        data = payload.model_dump_json()
        dead: list[WebSocket] = []
        for ws in list(self._clients):
            try:
                await ws.send_text(data)
            except Exception:  # noqa: BLE001
                dead.append(ws)
        for ws in dead:
            await self.disconnect(ws)


realtime = RealtimeManager()
