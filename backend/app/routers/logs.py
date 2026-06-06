from fastapi import APIRouter, Depends, HTTPException
from docker.errors import DockerException, NotFound

from app.models.schemas import LogsResponse
from app.services.auth import require_user
from app.services.docker_service import docker_service
from app.services.sanitization import sanitize_lines

router = APIRouter(prefix="/logs", tags=["logs"])


@router.get("/{container_id}", response_model=LogsResponse)
async def get_container_logs(
    container_id: str, tail: int = 100, _: dict = Depends(require_user)
) -> LogsResponse:
    if tail < 1 or tail > 1000:
        raise HTTPException(status_code=400, detail="tail must be between 1 and 1000")

    try:
        lines = docker_service.get_container_logs(container_id, tail=tail)
    except NotFound:
        raise HTTPException(status_code=404, detail=f"Container '{container_id}' not found")
    except DockerException as exc:
        raise HTTPException(status_code=503, detail=f"Docker error: {exc}")

    return LogsResponse(
        container_id=container_id,
        lines=lines,
        sanitized_lines=sanitize_lines(lines),
    )
