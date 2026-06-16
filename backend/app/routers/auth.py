import uuid

from fastapi import APIRouter, Depends, HTTPException

from app import db
from app.models.schemas import AuthRequest, AuthResponse, RegisterResponse
from app.services.auth import create_token, require_user
from app.services.crypto import hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=RegisterResponse)
async def register(req: AuthRequest) -> RegisterResponse:
    email = req.email.strip().lower()
    if not email or "@" not in email or len(req.password) < 6:
        raise HTTPException(status_code=400, detail="Valid email and 6+ char password required")
    if await db.get_user_by_email(email):
        raise HTTPException(status_code=409, detail="Email already registered")
    # First account = admin (auto-approved); everyone else waits for admin approval.
    first = await db.count_users() == 0
    role = "admin" if first else "viewer"
    uid = str(uuid.uuid4())
    await db.create_user(uid, email, hash_password(req.password), role, approved=first)
    if first:
        return RegisterResponse(
            pending=False,
            token=create_token(uid, email, role),
            email=email,
            role=role,
        )
    return RegisterResponse(pending=True, token=None, email=email, role=role)


@router.post("/login", response_model=AuthResponse)
async def login(req: AuthRequest) -> AuthResponse:
    email = req.email.strip().lower()
    user = await db.get_user_by_email(email)
    if not user or not verify_password(req.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    if not user.get("approved"):
        raise HTTPException(
            status_code=403, detail="Your account is pending admin approval"
        )
    return AuthResponse(
        token=create_token(
            user["id"], email, user["role"], int(user.get("token_version", 0))
        ),
        email=email,
        role=user["role"],
    )


@router.get("/me")
async def me(claims: dict = Depends(require_user)) -> dict:
    return {"email": claims.get("email"), "role": claims.get("role")}


@router.get("/verify")
async def verify(claims: dict = Depends(require_user)) -> dict:
    """Re-validate a token against the central DB (used by remote agents)."""
    return {"ok": True, "role": claims.get("role"), "email": claims.get("email")}


@router.post("/logout")
async def logout(claims: dict = Depends(require_user)) -> dict:
    """Revoke all of this user's tokens by bumping their token_version."""
    await db.bump_token_version(claims["sub"])
    return {"status": "ok"}
