"""Admin-editable runtime config, stored in the DB and overriding env defaults,
so notification channels / thresholds / AI budget can be set from the UI without
editing .env or redeploying. Central node only (it owns the DB)."""
from app import db
from app.config import settings

_cache: dict[str, str] = {}


async def refresh() -> None:
    try:
        rows = await db.get_all_config()
        _cache.clear()
        _cache.update(rows)
    except Exception:  # noqa: BLE001
        pass


def update(values: dict) -> None:
    """Apply changes to the in-memory cache immediately (after a DB write)."""
    for k, v in values.items():
        if v is None or v == "":
            _cache.pop(k, None)
        else:
            _cache[k] = str(v)


def _f(key: str, default: float) -> float:
    v = _cache.get(key)
    try:
        return float(v) if v not in (None, "") else default
    except (TypeError, ValueError):
        return default


def _i(key: str, default: int) -> int:
    v = _cache.get(key)
    try:
        return int(float(v)) if v not in (None, "") else default
    except (TypeError, ValueError):
        return default


# Typed accessors (DB override → env default)
def webhook_url() -> str:
    return _cache.get("alert_webhook_url") or settings.alert_webhook_url


def telegram_token() -> str:
    return _cache.get("telegram_bot_token") or settings.telegram_bot_token


def telegram_chat() -> str:
    return _cache.get("telegram_chat_id") or settings.telegram_chat_id


def cooldown() -> int:
    return _i("alert_cooldown_seconds", settings.alert_cooldown_seconds)


def cpu_default() -> float:
    return _f("cpu_alert_percent", settings.cpu_alert_percent)


def mem_default() -> float:
    return _f("mem_alert_percent", settings.mem_alert_percent)


def disk_default() -> float:
    return _f("disk_alert_percent", settings.disk_alert_percent)


def battery_default() -> float:
    return _f("battery_alert_percent", settings.battery_alert_percent)


def ai_budget() -> int:
    return _i("ai_monthly_token_budget", settings.ai_monthly_token_budget)


# Effective values for the admin UI (what's actually in force right now).
def effective() -> dict:
    return {
        "alert_webhook_url": webhook_url(),
        "telegram_bot_token": telegram_token(),
        "telegram_chat_id": telegram_chat(),
        "alert_cooldown_seconds": cooldown(),
        "cpu_alert_percent": cpu_default(),
        "mem_alert_percent": mem_default(),
        "disk_alert_percent": disk_default(),
        "battery_alert_percent": battery_default(),
        "ai_monthly_token_budget": ai_budget(),
    }
