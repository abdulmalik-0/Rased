import json
import uuid

from fastapi import APIRouter, Depends, HTTPException

from app import db
from app.models.schemas import (
    AIProviderConfig,
    ChatUpsert,
    DeviceOverride,
    LinkUpsert,
    UserUpdate,
)
from app.services.auth import require_admin, require_user
from app.services.crypto import decrypt, encrypt

router = APIRouter(tags=["data"])


# ---------- AI settings (per user) ----------
@router.get("/settings")
async def get_settings(claims: dict = Depends(require_user)):
    row = await db.get_settings(claims["sub"])
    if not row:
        return None
    return {
        "provider_type": row["provider_type"],
        "base_url": row["base_url"],
        "model_name": row["model_name"],
        "api_key": decrypt(row["api_key_enc"]),
    }


@router.post("/settings")
async def save_settings(
    config: AIProviderConfig, claims: dict = Depends(require_user)
) -> dict:
    await db.upsert_settings(
        claims["sub"],
        config.provider_type,
        config.base_url,
        config.model_name,
        encrypt(config.api_key) if config.api_key else "",
    )
    await db.insert_audit(
        claims.get("email", ""), "settings.save", config.provider_type, config.model_name
    )
    return {"status": "ok"}


# ---------- Users (admin) ----------
@router.get("/users")
async def get_users(_: dict = Depends(require_admin)) -> list[dict]:
    return await db.list_users()


@router.patch("/users/{uid}")
async def update_user(
    uid: str, body: UserUpdate, admin: dict = Depends(require_admin)
) -> dict:
    if body.role is not None:
        if body.role not in ("admin", "viewer"):
            raise HTTPException(status_code=400, detail="role must be admin or viewer")
        await db.set_user_role(uid, body.role)
    if body.approved is not None:
        await db.set_user_approved(uid, body.approved)
    await db.insert_audit(
        admin.get("email", ""), "user.update", uid,
        f"role={body.role} approved={body.approved}",
    )
    return {"status": "ok"}


# ---------- Devices ----------
@router.get("/devices")
async def get_devices(_: dict = Depends(require_user)) -> list[dict]:
    return await db.list_devices()


@router.patch("/devices/{host_id}")
async def update_device(
    host_id: str, body: DeviceOverride, admin: dict = Depends(require_admin)
) -> dict:
    await db.set_device_overrides(
        host_id,
        display_name=body.display_name,
        nut_host=body.nut_host,
        nut_ups_name=body.nut_ups_name,
    )
    await db.insert_audit(admin.get("email", ""), "device.update", host_id, "")
    return {"status": "ok"}


# ---------- Container links (admin-editable) ----------
@router.get("/links")
async def get_links(
    host_id: str = "default", _: dict = Depends(require_user)
) -> list[dict]:
    return await db.list_links(host_id)


@router.put("/links")
async def put_link(body: LinkUpsert, _: dict = Depends(require_admin)) -> dict:
    await db.upsert_link(body.host_id, body.name, body.url, body.label)
    return {"status": "ok"}


@router.delete("/links")
async def remove_link(
    host_id: str, name: str, _: dict = Depends(require_admin)
) -> dict:
    await db.delete_link(host_id, name)
    return {"status": "ok"}


# ---------- History & alerts ----------
@router.get("/history")
async def get_history(
    hours: int = 24, host_id: str | None = None, _: dict = Depends(require_user)
) -> list[dict]:
    return await db.bucketed_history(max(1, min(hours, 8760)), 200, host_id)


@router.get("/history/container/{name}")
async def get_container_history(
    name: str,
    hours: int = 24,
    host_id: str = "default",
    _: dict = Depends(require_user),
) -> list[dict]:
    return await db.container_history(max(1, min(hours, 8760)), host_id, name)


@router.get("/alerts")
async def get_alerts(
    host_id: str | None = None, limit: int = 100, _: dict = Depends(require_user)
) -> list[dict]:
    return await db.list_alerts(host_id, max(1, min(limit, 500)))


@router.get("/audit")
async def get_audit(limit: int = 200, _: dict = Depends(require_admin)) -> list[dict]:
    return await db.list_audit(max(1, min(limit, 1000)))


# ---------- AI chats ----------
@router.get("/chats")
async def get_chats(
    host_id: str = "default", claims: dict = Depends(require_user)
) -> list[dict]:
    rows = await db.list_chats(claims["sub"], host_id)
    for r in rows:
        r["messages"] = json.loads(r["messages"])
    return rows


@router.post("/chats")
async def upsert_chat(body: ChatUpsert, claims: dict = Depends(require_user)) -> dict:
    if body.id:
        await db.update_chat(body.id, claims["sub"], body.title, body.messages)
        return {"id": body.id}
    cid = str(uuid.uuid4())
    await db.insert_chat(cid, claims["sub"], body.host_id, body.title, body.messages)
    return {"id": cid}


@router.delete("/chats/{cid}")
async def remove_chat(cid: str, claims: dict = Depends(require_user)) -> dict:
    await db.delete_chat(cid, claims["sub"])
    return {"status": "ok"}
