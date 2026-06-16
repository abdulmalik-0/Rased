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
        clients = list(self._clients)
        if not clients:
            return

        async def _send(ws: WebSocket) -> WebSocket | None:
            try:
                await ws.send_text(data)
                return None
            except Exception:  # noqa: BLE001
                return ws

        # Fan out concurrently so one slow client doesn't stall the rest.
        results = await asyncio.gather(*(_send(ws) for ws in clients))
        for ws in results:
            if ws is not None:
                await self.disconnect(ws)


realtime = RealtimeManager()
