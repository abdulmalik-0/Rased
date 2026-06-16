import time

import httpx
import jwt
from fastapi import Header, HTTPException

from app import db
from app.config import settings

ALGO = "HS256"

# Cache of agent-side central verifications: token -> (expiry_monotonic, claims).
_verify_cache: dict[str, tuple[float, dict]] = {}
_CACHE_TTL = 30.0


def create_token(uid: str, email: str, role: str, token_version: int = 0) -> str:
    now = int(time.time())
    payload = {
        "sub": uid,
        "email": email,
        "role": role,
        "tv": token_version,
        "iat": now,
        "exp": now + settings.jwt_expiry_hours * 3600,
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=ALGO)


def _decode(token: str) -> dict:
    try:
        return jwt.decode(token, settings.jwt_secret, algorithms=[ALGO])
    except jwt.PyJWTError as exc:
        raise HTTPException(status_code=401, detail=f"Invalid token: {exc}")


def _token_from(authorization: str | None) -> str:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    return authorization.split(" ", 1)[1].strip()


async def _validate_central(claims: dict) -> dict:
    """On the central node the DB is the source of truth — re-check the user so a
    revoked/demoted/un-approved token stops working immediately."""
    user = await db.get_user_by_id(claims.get("sub", ""))
    if not user:
        raise HTTPException(status_code=401, detail="Account no longer exists")
    if not user.get("approved"):
        raise HTTPException(status_code=403, detail="Account is pending admin approval")
    if int(user.get("token_version", 0)) != int(claims.get("tv", 0)):
        raise HTTPException(status_code=401, detail="Session expired; sign in again")
    claims["role"] = user["role"]
    return claims


async def _validate_agent(token: str, claims: dict) -> dict:
    """On a remote agent, verify the token with the central node (cached) so a
    demoted/revoked user can't act here either. Fail-open if central is down."""
    now = time.monotonic()
    hit = _verify_cache.get(token)
    if hit and hit[0] > now:
        return hit[1]
    url = settings.central_ingest_url.rstrip("/") + "/auth/verify"
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(url, headers={"Authorization": f"Bearer {token}"})
        if resp.status_code == 200:
            claims["role"] = resp.json().get("role", claims.get("role"))
            _verify_cache[token] = (now + _CACHE_TTL, claims)
            return claims
        if resp.status_code in (401, 403):
            raise HTTPException(status_code=resp.status_code, detail="Not authorized")
    except HTTPException:
        raise
    except Exception:  # noqa: BLE001 — central unreachable: trust the signed claim
        pass
    return claims


async def require_user(authorization: str | None = Header(default=None)) -> dict:
    token = _token_from(authorization)
    claims = _decode(token)
    if settings.is_central:
        return await _validate_central(claims)
    return await _validate_agent(token, claims)


async def require_admin(authorization: str | None = Header(default=None)) -> dict:
    claims = await require_user(authorization)
    if claims.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")
    return claims


async def require_agent(authorization: str | None = Header(default=None)) -> None:
    """Shared-secret guard for remote agents posting to /ingest."""
    token = _token_from(authorization)
    if not settings.agent_token or token != settings.agent_token:
        raise HTTPException(status_code=401, detail="Invalid agent token")
