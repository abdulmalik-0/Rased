import asyncio
import logging
import time
from datetime import datetime, timezone

import httpx

from app import db
from app.config import settings
from app.models.schemas import (
    Alert,
    ContainerMetrics,
    HostStats,
    MetricsPayload,
    UpsStatus,
)
from app.services import app_config
from app.services.ai_router import analyze_logs, config_from_settings, daily_digest
from app.services.alert_service import alert_service
from app.services.docker_service import docker_service
from app.services.host_service import host_service
from app.services.nut_service import nut_service
from app.services.realtime import realtime
from app.services.uptime_service import uptime_service

logger = logging.getLogger(__name__)

DOWN_STATUSES = ("exited", "dead")
_last_history: dict[str, float] = {}


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


async def _nut_params() -> tuple[str | None, int | None, str | None]:
    """NUT target: per-device override from the DB (central) falls back to env."""
    host, port, ups = settings.nut_host, settings.nut_port, settings.nut_ups_name
    if settings.is_central:
        try:
            dev = await db.get_device(settings.host_id)
            if dev:
                host = dev.get("nut_host") or host
                ups = dev.get("nut_ups_name") or ups
        except Exception:  # noqa: BLE001
            pass
    return host, port, ups


def _collect_blocking(
    nut_host: str | None, nut_port: int | None, nut_ups: str | None
) -> tuple[list[ContainerMetrics], UpsStatus, HostStats]:
    ups = nut_service.get_status(nut_host, nut_port, nut_ups)
    host = host_service.get_stats()
    containers = docker_service.list_container_metrics()
    return containers, ups, host


def _assemble(
    containers: list[ContainerMetrics], ups: UpsStatus, host: HostStats
) -> MetricsPayload:
    return MetricsPayload(
        timestamp=_now_iso(),
        host_id=settings.host_id,
        host_name=settings.host_name,
        containers=containers,
        ups=ups,
        host=host,
        uptime=list(uptime_service.latest),
        alerts=alert_service.recent_for(settings.host_id),
    )


async def build_payload() -> MetricsPayload:
    """Local snapshot for the REST endpoint and AI context on this agent."""
    nh, nport, nu = await _nut_params()
    containers, ups, host = await asyncio.to_thread(_collect_blocking, nh, nport, nu)
    return _assemble(containers, ups, host)


def _summarize(payload: MetricsPayload) -> str:
    running = sum(1 for c in payload.containers if c.status == "running")
    down = [c.name for c in payload.containers if c.status in DOWN_STATUSES]
    lines = [
        f"Host: {payload.host_name} ({payload.host_id})",
        f"Time: {payload.timestamp}",
        f"Containers: {running} running / {len(payload.containers)} total",
    ]
    if payload.host.available:
        lines.append(
            f"Host CPU {payload.host.cpu_percent:.0f}% | "
            f"Mem {payload.host.memory_percent:.0f}%"
        )
        for d in payload.host.disks:
            lines.append(f"Disk {d.mount}: {d.percent:.0f}%")
    if down:
        lines.append("Down: " + ", ".join(down))
    if payload.containers:
        lines.append("Per-container (sorted by CPU):")
        for c in sorted(payload.containers, key=lambda x: x.cpu_percent, reverse=True):
            lines.append(
                f"- {c.name} [{c.status}] CPU {c.cpu_percent:.0f}% "
                f"RAM {c.memory_usage_mb:.0f}MB ({c.memory_percent:.0f}%) image={c.image}"
            )
    if payload.ups.connected:
        lines.append(
            f"UPS: {'on battery' if payload.ups.on_battery else 'on mains'}"
            + (
                f", battery {payload.ups.battery_charge_percent:.0f}%"
                if payload.ups.battery_charge_percent is not None
                else ""
            )
        )
    for u in payload.uptime:
        status = "UP" if u.up else "DOWN"
        cert = f", cert {u.cert_expiry_days}d" if u.cert_expiry_days is not None else ""
        lines.append(f"Uptime {u.name}: {status}{cert}")
    return "\n".join(lines)


async def process_payload(payload: MetricsPayload, api_url: str = "") -> None:
    """CENTRAL-side: store, fan out to WebSocket, evaluate alerts, persist."""
    await realtime.publish(payload)
    await db.upsert_device(payload.host_id, payload.host_name, api_url)

    alert_service.update_baselines(payload)
    alerts = alert_service.evaluate(payload)
    if alerts:
        await alert_service.dispatch(alerts, time.monotonic(), payload.host_id)

    if settings.history_enabled:
        now = time.monotonic()
        if now - _last_history.get(payload.host_id, 0.0) >= settings.history_interval_seconds:
            _last_history[payload.host_id] = now
            running = sum(1 for c in payload.containers if c.status == "running")
            disk_max = max((d.percent for d in payload.host.disks), default=0.0)
            try:
                await db.insert_history(
                    payload.timestamp, payload.host_id,
                    payload.host.cpu_percent if payload.host.available else None,
                    payload.host.memory_percent if payload.host.available else None,
                    disk_max, running, len(payload.containers),
                    payload.ups.on_battery, payload.ups.battery_charge_percent,
                    [{"name": c.name, "status": c.status, "cpu": c.cpu_percent,
                      "mem": c.memory_percent} for c in payload.containers],
                )
            except Exception as exc:  # noqa: BLE001
                logger.warning("History insert failed: %s", exc)


async def _post_to_central(payload: MetricsPayload) -> None:
    url = settings.central_ingest_url.rstrip("/") + "/ingest/metrics"
    headers = {
        "Authorization": f"Bearer {settings.agent_token}",
        "X-Agent-Url": settings.public_base_url,
        "Content-Type": "application/json",
    }
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            await client.post(url, headers=headers, json=payload.model_dump())
    except httpx.HTTPError as exc:
        logger.warning("Ingest to central failed: %s", exc)


async def _triage_container(container: ContainerMetrics) -> None:
    cfg = config_from_settings()
    if cfg is None:
        return
    try:
        logs = await asyncio.to_thread(docker_service.get_container_logs, container.id, 100)
        if not logs:
            return
        analysis, _ = await analyze_logs(logs, cfg)
        alert = Alert(level="critical", kind="triage", target=container.name,
                      message=f"{container.name} went {container.status}. "
                      f"AI triage: {analysis[:600]}", timestamp=_now_iso())
        if settings.is_central:
            await alert_service.dispatch([alert], time.monotonic(), settings.host_id)
        else:
            await alert_service._post(alert, settings.host_id)  # noqa: SLF001
        logger.info("Proactive triage sent for %s", container.name)
    except Exception as exc:  # noqa: BLE001
        logger.warning("Triage failed for %s: %s", container.name, exc)


def _maybe_triage(containers: list[ContainerMetrics], last_statuses: dict[str, str]) -> None:
    if not (settings.proactive_triage_enabled and config_from_settings()):
        return
    for c in containers:
        prev = last_statuses.get(c.id)
        if prev is not None and prev not in DOWN_STATUSES and c.status in DOWN_STATUSES:
            asyncio.create_task(_triage_container(c))


async def _maybe_digest(payload: MetricsPayload, last_day):
    if not (settings.digest_enabled and settings.is_central):
        return last_day
    cfg = config_from_settings()
    if cfg is None:
        return last_day
    now_dt = datetime.now(timezone.utc)
    if now_dt.hour == settings.digest_hour_utc and last_day != now_dt.date():
        try:
            text = await daily_digest(_summarize(payload), cfg)
            alert = Alert(level="info", kind="digest", target="daily",
                          message=text, timestamp=_now_iso())
            await alert_service.dispatch([alert], time.monotonic(), settings.host_id)
        except Exception as exc:  # noqa: BLE001
            logger.warning("Digest failed: %s", exc)
        return now_dt.date()
    return last_day


async def _maybe_maintain(last_day):
    """Daily prune of old history/alerts + WAL checkpoint, so the DB can't grow
    unbounded and fill the LXC it monitors."""
    if not settings.is_central:
        return last_day
    now_dt = datetime.now(timezone.utc)
    if now_dt.hour == settings.maintenance_hour_utc and last_day != now_dt.date():
        try:
            await db.prune_history(settings.history_retain_days)
            await db.prune_alerts(settings.alert_retain_days)
            await db.checkpoint_wal()
            logger.info("Maintenance: pruned history/alerts + WAL checkpoint")
        except Exception as exc:  # noqa: BLE001
            logger.warning("Maintenance failed: %s", exc)
        return now_dt.date()
    return last_day


async def _scan_dead_agents() -> None:
    """Alert when a remote agent stops reporting (the monitor monitoring itself)."""
    if not settings.is_central:
        return
    try:
        devices = await db.list_devices()
    except Exception:  # noqa: BLE001
        return
    threshold = settings.agent_stale_factor * max(5, settings.metrics_interval_seconds)
    now = datetime.now(timezone.utc)
    stale: list[Alert] = []
    for d in devices:
        if d["host_id"] == settings.host_id:
            continue
        last = d.get("last_seen")
        if not last:
            continue
        try:
            age = (now - datetime.fromisoformat(last)).total_seconds()
        except ValueError:
            continue
        if age > threshold:
            name = d.get("display_name") or d.get("host_name") or d["host_id"]
            stale.append(Alert(
                level="critical", kind="agent_offline", target=name,
                message=f"Agent '{name}' has not reported in {int(age)}s",
                timestamp=_now_iso()))
    if stale:
        await alert_service.dispatch(stale, time.monotonic(), settings.host_id)


async def collector_loop() -> None:
    interval = settings.metrics_interval_seconds
    last_uptime = 0.0
    last_statuses: dict[str, str] = {}
    last_digest_day = None
    last_maintenance_day = None
    last_agent_scan = 0.0

    logger.info(
        "Collector: central=%s alerts=%s uptime=%s ai=%s",
        settings.is_central, bool(settings.alert_webhook_url),
        bool(settings.uptime_targets), settings.ai_configured,
    )

    while True:
        try:
            now = time.monotonic()
            if settings.uptime_targets and (
                now - last_uptime >= settings.uptime_interval_seconds
                or not uptime_service.latest
            ):
                await uptime_service.refresh()
                last_uptime = now

            nh, nport, nu = await _nut_params()
            containers, ups, host = await asyncio.to_thread(
                _collect_blocking, nh, nport, nu
            )
            payload = _assemble(containers, ups, host)

            if settings.is_central:
                await process_payload(payload, settings.public_base_url)
            else:
                await _post_to_central(payload)

            _maybe_triage(containers, last_statuses)
            last_statuses = {c.id: c.status for c in containers}
            last_digest_day = await _maybe_digest(payload, last_digest_day)
            last_maintenance_day = await _maybe_maintain(last_maintenance_day)
            if settings.is_central and now - last_agent_scan >= 60:
                last_agent_scan = now
                await _scan_dead_agents()
                try:
                    alert_service.thresholds_cache = await db.all_thresholds()
                    await app_config.refresh()
                except Exception:  # noqa: BLE001
                    pass

        except asyncio.CancelledError:
            raise
        except Exception as exc:  # noqa: BLE001
            logger.exception("Collector tick failed: %s", exc)

        await asyncio.sleep(interval)
