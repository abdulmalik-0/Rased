from fastapi import APIRouter, Depends, HTTPException
from docker.errors import DockerException

from app import db
from app.config import settings
from app.models.schemas import AskRequest, AskResponse
from app.services.ai_router import ask_question
from app.services.auth import require_user
from app.services.collector import _summarize, build_payload
from app.services.docker_service import docker_service

router = APIRouter(prefix="/ask", tags=["ask"])


def _trend_context(hist: list[dict], alerts: list[dict]) -> str:
    """Compact 24h trend + recent alerts so the AI can answer 'why did X spike?'."""
    lines: list[str] = []
    cpu = [h["host_cpu"] for h in hist if h.get("host_cpu") is not None]
    mem = [h["host_mem"] for h in hist if h.get("host_mem") is not None]
    if cpu:
        lines.append(f"CPU 24h: avg {sum(cpu) / len(cpu):.0f}% peak {max(cpu):.0f}%")
    if mem:
        lines.append(f"Memory 24h: avg {sum(mem) / len(mem):.0f}% peak {max(mem):.0f}%")
    if alerts:
        lines.append("Recent alerts:")
        for a in alerts[:10]:
            lines.append(f"- [{a.get('level')}] {a.get('ts', '')[:16]} {a.get('message')}")
    return "Historical context (last 24h):\n" + "\n".join(lines) if lines else ""


@router.post("", response_model=AskResponse)
async def ask(request: AskRequest, claims: dict = Depends(require_user)) -> AskResponse:
    if not request.ai_config.base_url or not request.ai_config.model_name:
        raise HTTPException(
            status_code=400, detail="base_url and model_name are required"
        )

    payload = await build_payload()
    context = _summarize(payload)

    # RAG: pull the host's recent history + alerts into context (central only).
    if settings.is_central:
        try:
            hist = await db.bucketed_history(24, 40, payload.host_id)
            recent = await db.list_alerts(payload.host_id, 15)
            extra = _trend_context(hist, recent)
            if extra:
                context += "\n\n" + extra
        except Exception:  # noqa: BLE001
            pass

    if request.include_logs and request.container_id:
        try:
            logs = docker_service.get_container_logs(request.container_id, tail=100)
            if logs:
                context += "\n\nRecent logs:\n" + "\n".join(logs[-50:])
        except DockerException:
            pass

    try:
        answer = await ask_question(
            request.question, context, request.ai_config, request.history,
            request.lang, claims.get("sub", ""),
        )
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"AI provider error: {exc}")

    return AskResponse(answer=answer, model_used=request.ai_config.model_name)
