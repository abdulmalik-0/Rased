from fastapi import APIRouter, Depends, HTTPException
from docker.errors import DockerException

from app.models.schemas import AskRequest, AskResponse
from app.services.ai_router import ask_question
from app.services.auth import require_user
from app.services.collector import _summarize, build_payload
from app.services.docker_service import docker_service

router = APIRouter(prefix="/ask", tags=["ask"])


@router.post("", response_model=AskResponse)
async def ask(request: AskRequest, _: dict = Depends(require_user)) -> AskResponse:
    if not request.ai_config.base_url or not request.ai_config.model_name:
        raise HTTPException(
            status_code=400, detail="base_url and model_name are required"
        )

    payload = await build_payload()
    context = _summarize(payload)

    if request.include_logs and request.container_id:
        try:
            logs = docker_service.get_container_logs(request.container_id, tail=100)
            if logs:
                context += "\n\nRecent logs:\n" + "\n".join(logs[-50:])
        except DockerException:
            pass

    try:
        answer = await ask_question(
            request.question, context, request.ai_config, request.history, request.lang
        )
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"AI provider error: {exc}")

    return AskResponse(answer=answer, model_used=request.ai_config.model_name)
