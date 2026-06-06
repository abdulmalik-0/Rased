from fastapi import APIRouter, Depends, Header

from app.models.schemas import MetricsPayload
from app.services.auth import require_agent
from app.services.collector import process_payload

router = APIRouter(prefix="/ingest", tags=["ingest"])


@router.post("/metrics")
async def ingest_metrics(
    payload: MetricsPayload,
    _: None = Depends(require_agent),
    x_agent_url: str | None = Header(default=None),
) -> dict:
    await process_payload(payload, x_agent_url or "")
    return {"status": "ok"}
