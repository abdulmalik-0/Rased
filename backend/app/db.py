import json
import os
from datetime import datetime, timezone

import aiosqlite

from app.config import settings

_db: aiosqlite.Connection | None = None

SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'viewer',
    approved INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS settings (
    user_id TEXT PRIMARY KEY,
    provider_type TEXT NOT NULL DEFAULT 'custom',
    base_url TEXT NOT NULL DEFAULT '',
    model_name TEXT NOT NULL DEFAULT '',
    api_key_enc TEXT NOT NULL DEFAULT '',
    updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS devices (
    host_id TEXT PRIMARY KEY,
    host_name TEXT NOT NULL DEFAULT '',
    display_name TEXT NOT NULL DEFAULT '',
    api_url TEXT NOT NULL DEFAULT '',
    nut_host TEXT NOT NULL DEFAULT '',
    nut_ups_name TEXT NOT NULL DEFAULT '',
    last_seen TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS container_links (
    host_id TEXT NOT NULL,
    name TEXT NOT NULL,
    url TEXT NOT NULL DEFAULT '',
    label TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (host_id, name)
);
CREATE TABLE IF NOT EXISTS metrics_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts TEXT NOT NULL,
    host_id TEXT NOT NULL,
    host_cpu REAL,
    host_mem REAL,
    host_disk_max REAL,
    containers_running INTEGER,
    containers_total INTEGER,
    ups_on_battery INTEGER,
    battery REAL,
    containers TEXT
);
CREATE INDEX IF NOT EXISTS idx_mh_ts ON metrics_history(ts);
CREATE TABLE IF NOT EXISTS alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts TEXT NOT NULL,
    host_id TEXT,
    level TEXT,
    kind TEXT,
    target TEXT,
    message TEXT,
    value REAL
);
CREATE TABLE IF NOT EXISTS ai_chats (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    host_id TEXT NOT NULL DEFAULT 'default',
    title TEXT NOT NULL DEFAULT 'Chat',
    messages TEXT NOT NULL DEFAULT '[]',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
"""


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


async def init_db() -> None:
    global _db
    os.makedirs(os.path.dirname(settings.db_path) or ".", exist_ok=True)
    _db = await aiosqlite.connect(settings.db_path)
    _db.row_factory = aiosqlite.Row
    await _db.execute("PRAGMA journal_mode=WAL;")
    await _db.executescript(SCHEMA)
    await _db.commit()
    # Backward-compat for DBs created before 'approved' existed (default them approved).
    try:
        await _db.execute(
            "ALTER TABLE users ADD COLUMN approved INTEGER NOT NULL DEFAULT 1"
        )
        await _db.commit()
    except Exception:
        pass
    for col in (
        "display_name TEXT NOT NULL DEFAULT ''",
        "nut_host TEXT NOT NULL DEFAULT ''",
        "nut_ups_name TEXT NOT NULL DEFAULT ''",
    ):
        try:
            await _db.execute(f"ALTER TABLE devices ADD COLUMN {col}")
            await _db.commit()
        except Exception:
            pass


async def close_db() -> None:
    if _db is not None:
        await _db.close()


def conn() -> aiosqlite.Connection:
    if _db is None:
        raise RuntimeError("DB not initialized")
    return _db


# ---------- users ----------
async def count_users() -> int:
    async with conn().execute("SELECT count(*) AS c FROM users") as cur:
        row = await cur.fetchone()
        return int(row["c"])


async def create_user(
    uid: str, email: str, password_hash: str, role: str, approved: bool = False
) -> None:
    await conn().execute(
        "INSERT INTO users (id, email, password_hash, role, approved, created_at) "
        "VALUES (?,?,?,?,?,?)",
        (uid, email, password_hash, role, 1 if approved else 0, _now()),
    )
    await conn().commit()


async def set_user_approved(uid: str, approved: bool) -> None:
    await conn().execute(
        "UPDATE users SET approved = ? WHERE id = ?", (1 if approved else 0, uid)
    )
    await conn().commit()


async def get_user_by_email(email: str) -> dict | None:
    async with conn().execute(
        "SELECT * FROM users WHERE email = ?", (email,)
    ) as cur:
        row = await cur.fetchone()
        return dict(row) if row else None


async def list_users() -> list[dict]:
    async with conn().execute(
        "SELECT id, email, role, approved, created_at FROM users ORDER BY created_at"
    ) as cur:
        return [dict(r) for r in await cur.fetchall()]


async def set_user_role(uid: str, role: str) -> None:
    await conn().execute("UPDATE users SET role = ? WHERE id = ?", (role, uid))
    await conn().commit()


# ---------- settings ----------
async def get_settings(user_id: str) -> dict | None:
    async with conn().execute(
        "SELECT * FROM settings WHERE user_id = ?", (user_id,)
    ) as cur:
        row = await cur.fetchone()
        return dict(row) if row else None


async def upsert_settings(
    user_id: str, provider_type: str, base_url: str, model_name: str, api_key_enc: str
) -> None:
    await conn().execute(
        """
        INSERT INTO settings (user_id, provider_type, base_url, model_name, api_key_enc, updated_at)
        VALUES (?,?,?,?,?,?)
        ON CONFLICT(user_id) DO UPDATE SET
            provider_type=excluded.provider_type,
            base_url=excluded.base_url,
            model_name=excluded.model_name,
            api_key_enc=CASE WHEN excluded.api_key_enc <> '' THEN excluded.api_key_enc ELSE settings.api_key_enc END,
            updated_at=excluded.updated_at
        """,
        (user_id, provider_type, base_url, model_name, api_key_enc, _now()),
    )
    await conn().commit()


# ---------- devices ----------
async def upsert_device(host_id: str, host_name: str, api_url: str) -> None:
    await conn().execute(
        """
        INSERT INTO devices (host_id, host_name, api_url, last_seen)
        VALUES (?,?,?,?)
        ON CONFLICT(host_id) DO UPDATE SET
            host_name=excluded.host_name, api_url=excluded.api_url, last_seen=excluded.last_seen
        """,
        (host_id, host_name, api_url, _now()),
    )
    await conn().commit()


async def list_devices() -> list[dict]:
    async with conn().execute(
        "SELECT host_id, host_name, display_name, api_url, nut_host, nut_ups_name, "
        "last_seen FROM devices ORDER BY host_name"
    ) as cur:
        return [dict(r) for r in await cur.fetchall()]


async def get_device(host_id: str) -> dict | None:
    async with conn().execute(
        "SELECT * FROM devices WHERE host_id = ?", (host_id,)
    ) as cur:
        row = await cur.fetchone()
        return dict(row) if row else None


async def set_device_overrides(
    host_id: str,
    display_name: str | None = None,
    nut_host: str | None = None,
    nut_ups_name: str | None = None,
) -> None:
    await conn().execute(
        "INSERT OR IGNORE INTO devices (host_id, last_seen) VALUES (?, ?)",
        (host_id, _now()),
    )
    sets, params = [], []
    if display_name is not None:
        sets.append("display_name = ?")
        params.append(display_name)
    if nut_host is not None:
        sets.append("nut_host = ?")
        params.append(nut_host)
    if nut_ups_name is not None:
        sets.append("nut_ups_name = ?")
        params.append(nut_ups_name)
    if sets:
        params.append(host_id)
        await conn().execute(
            f"UPDATE devices SET {', '.join(sets)} WHERE host_id = ?", params
        )
    await conn().commit()


# ---------- container links (admin-editable) ----------
async def list_links(host_id: str) -> list[dict]:
    async with conn().execute(
        "SELECT name, url, label FROM container_links WHERE host_id = ?", (host_id,)
    ) as cur:
        return [dict(r) for r in await cur.fetchall()]


async def upsert_link(host_id: str, name: str, url: str, label: str) -> None:
    await conn().execute(
        """
        INSERT INTO container_links (host_id, name, url, label) VALUES (?,?,?,?)
        ON CONFLICT(host_id, name) DO UPDATE SET url=excluded.url, label=excluded.label
        """,
        (host_id, name, url, label),
    )
    await conn().commit()


async def delete_link(host_id: str, name: str) -> None:
    await conn().execute(
        "DELETE FROM container_links WHERE host_id = ? AND name = ?", (host_id, name)
    )
    await conn().commit()


# ---------- history ----------
async def insert_history(
    ts: str,
    host_id: str,
    host_cpu,
    host_mem,
    host_disk_max,
    containers_running,
    containers_total,
    ups_on_battery,
    battery,
    containers: list,
) -> None:
    await conn().execute(
        """
        INSERT INTO metrics_history
        (ts, host_id, host_cpu, host_mem, host_disk_max, containers_running,
         containers_total, ups_on_battery, battery, containers)
        VALUES (?,?,?,?,?,?,?,?,?,?)
        """,
        (
            ts,
            host_id,
            host_cpu,
            host_mem,
            host_disk_max,
            containers_running,
            containers_total,
            1 if ups_on_battery else 0,
            battery,
            json.dumps(containers),
        ),
    )
    await conn().commit()


async def bucketed_history(hours: int, buckets: int = 200) -> list[dict]:
    bucket_secs = max(1, (hours * 3600) // max(1, buckets))
    since = datetime.now(timezone.utc).timestamp() - hours * 3600
    sql = """
        SELECT
            CAST(strftime('%s', ts) AS INTEGER) / ? * ? AS bucket,
            AVG(host_cpu) AS host_cpu,
            AVG(host_mem) AS host_mem,
            MAX(host_disk_max) AS host_disk_max,
            MAX(containers_running) AS containers_running
        FROM metrics_history
        WHERE strftime('%s', ts) >= ?
        GROUP BY bucket
        ORDER BY bucket
    """
    async with conn().execute(
        sql, (bucket_secs, bucket_secs, int(since))
    ) as cur:
        rows = await cur.fetchall()
    return [
        {
            "ts": datetime.fromtimestamp(
                int(r["bucket"]), tz=timezone.utc
            ).isoformat(),
            "host_cpu": r["host_cpu"],
            "host_mem": r["host_mem"],
            "host_disk_max": r["host_disk_max"],
            "containers_running": r["containers_running"],
        }
        for r in rows
    ]


async def prune_history(retain_days: int = 14) -> None:
    cutoff = (
        datetime.now(timezone.utc).timestamp() - retain_days * 86400
    )
    await conn().execute(
        "DELETE FROM metrics_history WHERE strftime('%s', ts) < ?", (int(cutoff),)
    )
    await conn().commit()


# ---------- alerts ----------
async def insert_alert(
    ts: str, host_id: str, level: str, kind: str, target: str, message: str, value
) -> None:
    await conn().execute(
        "INSERT INTO alerts (ts, host_id, level, kind, target, message, value) "
        "VALUES (?,?,?,?,?,?,?)",
        (ts, host_id, level, kind, target, message, value),
    )
    await conn().commit()


# ---------- ai_chats ----------
async def list_chats(user_id: str, host_id: str) -> list[dict]:
    async with conn().execute(
        "SELECT id, title, messages, updated_at FROM ai_chats "
        "WHERE user_id = ? AND host_id = ? ORDER BY updated_at DESC",
        (user_id, host_id),
    ) as cur:
        return [dict(r) for r in await cur.fetchall()]


async def insert_chat(
    cid: str, user_id: str, host_id: str, title: str, messages: list
) -> None:
    now = _now()
    await conn().execute(
        "INSERT INTO ai_chats (id, user_id, host_id, title, messages, created_at, updated_at) "
        "VALUES (?,?,?,?,?,?,?)",
        (cid, user_id, host_id, title, json.dumps(messages), now, now),
    )
    await conn().commit()


async def update_chat(
    cid: str, user_id: str, title: str, messages: list
) -> None:
    await conn().execute(
        "UPDATE ai_chats SET title = ?, messages = ?, updated_at = ? "
        "WHERE id = ? AND user_id = ?",
        (title, json.dumps(messages), _now(), cid, user_id),
    )
    await conn().commit()


async def delete_chat(cid: str, user_id: str) -> None:
    await conn().execute(
        "DELETE FROM ai_chats WHERE id = ? AND user_id = ?", (cid, user_id)
    )
    await conn().commit()
