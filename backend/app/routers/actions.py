from fastapi import APIRouter, Depends, HTTPException
from docker.errors import DockerException, NotFound

from app.models.schemas import ContainerActionRequest, ContainerActionResponse
from app.services.auth import require_admin
from app.services.docker_service import ALLOWED_ACTIONS, docker_service

router = APIRouter(prefix="/actions", tags=["actions"])


@router.post("/{container_id}", response_model=ContainerActionResponse)
async def container_action(
    container_id: str,
    request: ContainerActionRequest,
    _admin: dict = Depends(require_admin),
) -> ContainerActionResponse:
    action = request.action.lower().strip()
    if action not in ALLOWED_ACTIONS:
        raise HTTPException(
            status_code=400,
            detail=f"action must be one of {', '.join(ALLOWED_ACTIONS)}",
        )

    try:
        status = docker_service.container_action(container_id, action)
    except NotFound:
        raise HTTPException(
            status_code=404, detail=f"Container '{container_id}' not found"
        )
    except DockerException as exc:
        raise HTTPException(status_code=503, detail=f"Docker error: {exc}")

    return ContainerActionResponse(
        container_id=container_id,
        action=action,
        status=status,
        message=f"Container {action} succeeded (status: {status})",
    )
