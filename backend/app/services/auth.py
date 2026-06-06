import time

import jwt
from fastapi import Header, HTTPException

from app.config import settings

ALGO = "HS256"


def create_token(uid: str, email: str, role: str) -> str:
    now = int(time.time())
    payload = {
        "sub": uid,
        "email": email,
        "role": role,
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


async def require_user(authorization: str | None = Header(default=None)) -> dict:
    return _decode(_token_from(authorization))


async def require_admin(authorization: str | None = Header(default=None)) -> dict:
    claims = _decode(_token_from(authorization))
    if claims.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Admin role required")
    return claims


async def require_agent(authorization: str | None = Header(default=None)) -> None:
    """Shared-secret guard for remote agents posting to /ingest."""
    token = _token_from(authorization)
    if not settings.agent_token or token != settings.agent_token:
        raise HTTPException(status_code=401, detail="Invalid agent token")
