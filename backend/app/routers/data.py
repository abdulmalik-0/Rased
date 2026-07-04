import json
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException

from app import db
import os
import tempfile

from fastapi.responses import FileResponse

from app.config import settings
from app.models.schemas import (
    AIProviderConfig,
    AppConfigUpdate,
    ChatUpsert,
    DigestRequest,
    DigestResponse,
    DeviceOverride,
    LinkUpsert,
    ThresholdUpdate,
    UserUpdate,
)
from app.services import ai_router, app_config
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


# ---------- Weekly AI digest (on-demand) ----------
def _metric_line(name: str, hist: list[dict], key: str) -> str:
    vals = [float(r[key]) for r in hist if r.get(key) is not None]
    if not vals:
        return f"- {name}: no data"
    return (
        f"- {name}: now {vals[-1]:.0f}%, avg {sum(vals) / len(vals):.0f}%, "
        f"peak {max(vals):.0f}%, change {vals[-1] - vals[0]:+.0f} pts over the window"
    )


def _build_digest_summary(
    host_id: str, days: int, hist: list[dict], alerts: list[dict]
) -> str:
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    by_level: dict[str, int] = {}
    by_kind: dict[str, int] = {}
    notable: list[str] = []
    for a in alerts:
        try:
            ts = datetime.fromisoformat(str(a["ts"]).replace("Z", "+00:00"))
        except ValueError:
            continue
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        if ts < cutoff:
            continue
        by_level[a["level"]] = by_level.get(a["level"], 0) + 1
        by_kind[a["kind"]] = by_kind.get(a["kind"], 0) + 1
        if a["level"] in ("critical", "warning") and len(notable) < 8:
            notable.append(f"- [{a['level']}] {a['message']}")

    running = hist[-1].get("containers_running") if hist else None
    lines = [
        f"Server: {host_id}",
        f"Window: last {days} days ({len(hist)} history samples)",
        _metric_line("Host CPU", hist, "host_cpu"),
        _metric_line("Host memory", hist, "host_mem"),
        _metric_line("Disk (busiest mount)", hist, "host_disk_max"),
        f"- Containers running (latest): {running if running is not None else 'n/a'}",
        f"Alerts in window: {sum(by_level.values())} total"
        f" — by level {by_level or '{}'} — by kind {by_kind or '{}'}",
    ]
    if notable:
        lines.append("Notable alerts:")
        lines.extend(notable)
    return "\n".join(lines)


@router.post("/digest", response_model=DigestResponse)
async def generate_digest(
    req: DigestRequest, claims: dict = Depends(require_user)
) -> DigestResponse:
    if not req.ai_config.base_url or not req.ai_config.model_name:
        raise HTTPException(400, "AI provider not configured")
    days = max(1, min(31, req.days))
    hist = await db.bucketed_history(days * 24, 200, req.host_id)
    alerts = await db.list_alerts(req.host_id, limit=1000)
    summary = _build_digest_summary(req.host_id, days, hist, alerts)
    text = await ai_router.weekly_digest(
        summary, req.ai_config, req.lang, claims["sub"]
    )
    return DigestResponse(
        digest=text, model_used=req.ai_config.model_name, range_days=days
    )


@router.get("/alerts")
async def get_alerts(
    host_id: str | None = None, limit: int = 100, _: dict = Depends(require_user)
) -> list[dict]:
    return await db.list_alerts(host_id, max(1, min(limit, 500)))


@router.get("/audit")
async def get_audit(limit: int = 200, _: dict = Depends(require_admin)) -> list[dict]:
    return await db.list_audit(max(1, min(limit, 1000)))


@router.patch("/alerts/{alert_id}")
async def patch_alert(
    alert_id: int, action: str = "ack", _: dict = Depends(require_user)
) -> dict:
    if action == "resolve":
        await db.resolve_alert(alert_id)
    else:
        await db.ack_alert(alert_id)
    return {"status": "ok"}


# ---------- per-host alert thresholds ----------
@router.get("/thresholds")
async def get_thresholds(host_id: str, _: dict = Depends(require_user)) -> dict:
    return (await db.get_thresholds(host_id)) or {}


@router.put("/thresholds")
async def put_thresholds(body: ThresholdUpdate, admin: dict = Depends(require_admin)) -> dict:
    await db.set_thresholds(
        body.host_id, body.cpu, body.mem, body.disk, body.battery
    )
    await db.insert_audit(admin.get("email", ""), "thresholds.set", body.host_id, "")
    return {"status": "ok"}


# ---------- AI usage accounting (admin) ----------
@router.get("/usage")
async def get_usage(_: dict = Depends(require_admin)) -> list[dict]:
    return await db.usage_summary()


# ---------- DB backup (admin) ----------
@router.get("/admin/backup")
async def backup_db(admin: dict = Depends(require_admin)):
    path = os.path.join(tempfile.gettempdir(), "rased-backup.db")
    await db.backup_to(path)
    await db.insert_audit(admin.get("email", ""), "db.backup", "", "")
    return FileResponse(
        path, media_type="application/octet-stream", filename="rased-backup.db"
    )


# ---------- Runtime config (admin-editable; overrides .env) ----------
@router.get("/admin/config")
async def get_admin_config(_: dict = Depends(require_admin)) -> dict:
    return app_config.effective()


@router.put("/admin/config")
async def set_admin_config(
    body: AppConfigUpdate, admin: dict = Depends(require_admin)
) -> dict:
    values = body.model_dump(exclude_unset=True)
    await db.set_config_many(values)
    app_config.update(values)
    await db.insert_audit(
        admin.get("email", ""), "config.update", "", ",".join(values.keys())
    )
    return app_config.effective()


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
