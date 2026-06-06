"""Admin-only onboarding helpers: generate a ready-to-run agent setup so linking
a new machine is copy-paste simple (real secrets prefilled, no manual editing)."""
from urllib.parse import urlparse

from fastapi import APIRouter, Depends, Request

from app.config import settings
from app.services.auth import require_admin

router = APIRouter(prefix="/setup", tags=["setup"])


def _central_base(request: Request) -> str:
    """The URL a remote agent should POST metrics to (this central node)."""
    if settings.public_base_url:
        return settings.public_base_url.rstrip("/")
    return str(request.base_url).rstrip("/")


@router.get("/agent")
async def agent_setup(request: Request, _: dict = Depends(require_admin)) -> dict:
    """Everything needed to link a new machine, with the real shared secrets."""
    central = _central_base(request)
    host = urlparse(central).hostname or "CENTRAL_IP"
    ui_origin = f"http://{host}:8082"

    env_agent = "\n".join(
        [
            "RASED_API_PORT=8002",
            "RASED_HOST_ID=lxc-2",
            "RASED_HOST_NAME=LXC 2",
            "RASED_PUBLIC_BASE_URL=http://THIS_MACHINE_IP:8002",
            f"CENTRAL_INGEST_URL={central}",
            f"AGENT_TOKEN={settings.agent_token}",
            f"JWT_SECRET={settings.jwt_secret}",
            f"RASED_CORS_ORIGINS={ui_origin}",
        ]
    )

    # One command on the new machine (after copying the Rased folder there).
    command = (
        "bash scripts/install-agent.sh"
        f" --central {central}"
        f" --token {settings.agent_token}"
        f" --jwt {settings.jwt_secret}"
        ' --id lxc-2 --name "LXC 2"'
    )

    # How to copy the project to the new machine (run on the central node).
    copy_command = "scp -r ~/rased USER@THIS_MACHINE_IP:~/"

    return {
        "central_ingest_url": central,
        "agent_token": settings.agent_token,
        "jwt_secret": settings.jwt_secret,
        "ui_origin": ui_origin,
        "copy_command": copy_command,
        "command": command,
        "env_agent": env_agent,
        "token_set": bool(settings.agent_token),
    }
