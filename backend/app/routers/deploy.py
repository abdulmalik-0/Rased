"""Admin-only AI deploy. Two safety tiers:
  • /suggest  → free-text docker run/compose for the admin to copy & run.
  • /plan     → a STRUCTURED plan the admin reviews.
  • /run      → installs a reviewed plan via the Docker SDK (no shell). Gated by
                require_admin AND settings.allow_container_deploy."""
from docker.errors import APIError, DockerException, ImageNotFound
from fastapi import APIRouter, Depends, HTTPException

from app import db
from app.config import settings
from app.models.schemas import (
    DeployImageRequest,
    DeployPlan,
    DeployPlanRequest,
    DeployRunResponse,
    DeploySuggestRequest,
    DeploySuggestResponse,
)
from app.services import ai_router
from app.services.auth import require_admin
from app.services.docker_service import docker_service

router = APIRouter(prefix="/deploy", tags=["deploy"])


@router.post("/suggest", response_model=DeploySuggestResponse)
async def suggest_deploy(
    req: DeploySuggestRequest,
    _admin: dict = Depends(require_admin),
) -> DeploySuggestResponse:
    if not req.description.strip():
        raise HTTPException(status_code=400, detail="description is required")
    try:
        text = await ai_router.suggest_deploy(req.description, req.ai_config, req.lang)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return DeploySuggestResponse(suggestion=text, model_used=req.ai_config.model_name)


@router.post("/plan", response_model=DeployPlan)
async def plan_deploy(
    req: DeployPlanRequest,
    _admin: dict = Depends(require_admin),
) -> DeployPlan:
    if not req.description.strip():
        raise HTTPException(status_code=400, detail="description is required")
    try:
        spec = await ai_router.plan_deploy(req.description, req.ai_config, req.lang)
        return DeployPlan(**spec)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception as exc:  # noqa: BLE001 — surface a bad AI plan as 400
        raise HTTPException(status_code=400, detail=f"Invalid plan: {exc}")


@router.post("/run", response_model=DeployRunResponse)
async def run_deploy(
    plan: DeployPlan,
    admin: dict = Depends(require_admin),
) -> DeployRunResponse:
    if not settings.allow_container_deploy:
        raise HTTPException(
            status_code=403,
            detail="Container deploy is disabled (set ALLOW_CONTAINER_DEPLOY=true)",
        )
    try:
        result = docker_service.run_container(plan.model_dump())
    except ImageNotFound:
        raise HTTPException(status_code=404, detail=f"Image not found: {plan.image}")
    except (APIError, DockerException) as exc:
        raise HTTPException(status_code=400, detail=f"Docker error: {exc}")
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    await db.insert_audit(admin.get("email", ""), "deploy.run", plan.image, plan.name)
    return DeployRunResponse(**result)


@router.post("/image", response_model=DeployRunResponse)
async def run_image(
    req: DeployImageRequest,
    admin: dict = Depends(require_admin),
) -> DeployRunResponse:
    """Pull and run an image directly (auto-publishing its ports to free ones)."""
    if not settings.allow_container_deploy:
        raise HTTPException(
            status_code=403,
            detail="Container deploy is disabled (set ALLOW_CONTAINER_DEPLOY=true)",
        )
    if not req.image.strip():
        raise HTTPException(status_code=400, detail="image is required")
    try:
        result = docker_service.run_image(req.image, req.name)
    except ImageNotFound:
        raise HTTPException(status_code=404, detail=f"Image not found: {req.image}")
    except (APIError, DockerException) as exc:
        raise HTTPException(status_code=400, detail=f"Docker error: {exc}")
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    await db.insert_audit(admin.get("email", ""), "deploy.image", req.image, "")
    return DeployRunResponse(**result)
