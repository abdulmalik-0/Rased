from fastapi import APIRouter, HTTPException
from docker.errors import DockerException, NotFound

from app.models.schemas import AnalyzeRequest, AnalyzeResponse
from app.services.ai_router import analyze_logs
from app.services.docker_service import docker_service

router = APIRouter(prefix="/analyze", tags=["analyze"])


@router.post("", response_model=AnalyzeResponse)
async def analyze_container_logs(request: AnalyzeRequest) -> AnalyzeResponse:
    if not request.ai_config.base_url or not request.ai_config.model_name:
        raise HTTPException(
            status_code=400,
            detail="base_url and model_name are required",
        )

    try:
        logs = docker_service.get_container_logs(request.container_id, tail=100)
    except NotFound:
        raise HTTPException(
            status_code=404,
            detail=f"Container '{request.container_id}' not found",
        )
    except DockerException as exc:
        raise HTTPException(status_code=503, detail=f"Docker error: {exc}")

    if not logs:
        raise HTTPException(status_code=404, detail="No logs found for container")

    try:
        analysis, preview = await analyze_logs(
            logs,
            request.ai_config,
            request.custom_prompt,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"AI provider error: {exc}",
        )

    return AnalyzeResponse(
        analysis=analysis,
        sanitized_log_preview=preview,
        model_used=request.ai_config.model_name,
    )
