"""Admin-only: ask the AI to SUGGEST a docker run / compose for a service.
The AI never executes anything — the admin reviews the snippet and runs it."""
from fastapi import APIRouter, Depends, HTTPException

from app.models.schemas import DeploySuggestRequest, DeploySuggestResponse
from app.services import ai_router
from app.services.auth import require_admin

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
