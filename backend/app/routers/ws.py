import jwt
from fastapi import APIRouter, WebSocket

from app.config import settings
from app.services.realtime import realtime

router = APIRouter()


@router.websocket("/ws/metrics")
async def ws_metrics(websocket: WebSocket) -> None:
    token = websocket.query_params.get("token", "")
    try:
        jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
    except jwt.PyJWTError:
        await websocket.close(code=1008)
        return

    await realtime.connect(websocket)
    try:
        while True:
            # We only push; reading detects client disconnect.
            await websocket.receive_text()
    except Exception:  # noqa: BLE001 - normal on disconnect
        pass
    finally:
        await realtime.disconnect(websocket)
