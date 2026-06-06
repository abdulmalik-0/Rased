import logging

import httpx
import jwt
from fastapi import Header, HTTPException

from app.config import settings

logger = logging.getLogger(__name__)


def _extract_token(authorization: str | None) -> str:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    return authorization.split(" ", 1)[1].strip()


def _decode(token: str) -> dict:
    if not settings.supabase_jwt_secret:
        # Auth not configured — refuse privileged actions rather than allow them.
        raise HTTPException(
            status_code=503,
            detail="Auth not configured on the server (SUPABASE_JWT_SECRET missing)",
        )
    try:
        return jwt.decode(
            token,
            settings.supabase_jwt_secret,
            algorithms=["HS256"],
            audience="authenticated",
        )
    except jwt.PyJWTError as exc:
        raise HTTPException(status_code=401, detail=f"Invalid token: {exc}")


async def _get_role(user_id: str) -> str:
    """Read the user's role from the profiles table (service_role bypasses RLS)."""
    if not (settings.supabase_url and settings.supabase_service_role_key):
        return "viewer"
    url = f"{settings.supabase_url.rstrip('/')}/rest/v1/profiles"
    headers = {
        "apikey": settings.supabase_service_role_key,
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
    }
    params = {"id": f"eq.{user_id}", "select": "role"}
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(url, headers=headers, params=params)
            if resp.status_code == 200:
                rows = resp.json()
                if rows:
                    return rows[0].get("role", "viewer")
    except httpx.HTTPError as exc:
        logger.warning("Role lookup failed: %s", exc)
    return "viewer"


async def require_admin(authorization: str | None = Header(default=None)) -> dict:
    """FastAPI dependency: allow only authenticated users whose profile role is admin."""
    claims = _decode(_extract_token(authorization))
    user_id = claims.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token (no subject)")
    role = await _get_role(user_id)
    if role != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")
    return claims
