import asyncio
import logging
import time
from datetime import datetime, timezone

from app.config import settings
from app.models.schemas import (
    Alert,
    ContainerMetrics,
    HostStats,
    MetricsPayload,
    UpsStatus,
)
from app.services.ai_router import analyze_logs, config_from_settings, daily_digest
from app.services.alert_service import alert_service
from app.services.broadcast import broadcast_service
from app.services.device_service import device_service
from app.services.docker_service import docker_service
from app.services.history_service import history_service
from app.services.host_service import host_service
from app.services.nut_service import nut_service
from app.services.uptime_service import uptime_service

logger = logging.getLogger(__name__)

DOWN_STATUSES = ("exited", "dead")


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _collect_blocking() -> tuple[list[ContainerMetrics], UpsStatus, HostStats]:
    """Blocking metric collection (Docker + NUT + psutil), run in a thread."""
    ups = nut_service.get_status()
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
        alerts=alert_service.recent[-10:],
    )


async def build_payload() -> MetricsPayload:
    """Assemble a full snapshot for the REST fallback endpoint."""
    containers, ups, host = await asyncio.to_thread(_collect_blocking)
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
        for c in sorted(
            payload.containers, key=lambda x: x.cpu_percent, reverse=True
        ):
            lines.append(
                f"- {c.name} [{c.status}] CPU {c.cpu_percent:.0f}% "
                f"RAM {c.memory_usage_mb:.0f}MB ({c.memory_percent:.0f}%) "
                f"image={c.image}"
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
        cert = (
            f", cert {u.cert_expiry_days}d"
            if u.cert_expiry_days is not None
            else ""
        )
        lines.append(f"Uptime {u.name}: {status}{cert}")
    return "\n".join(lines)


async def _triage_container(container: ContainerMetrics) -> None:
    cfg = config_from_settings()
    if cfg is None:
        return
    try:
        logs = await asyncio.to_thread(
            docker_service.get_container_logs, container.id, 100
        )
        if not logs:
            return
        analysis, _ = await analyze_logs(logs, cfg)
        alert = Alert(
            level="critical",
            kind="triage",
            target=container.name,
            message=f"{container.name} went {container.status}. "
            f"AI triage: {analysis[:600]}",
            timestamp=_now_iso(),
        )
        await alert_service.dispatch([alert], time.monotonic())
        logger.info("Proactive triage sent for %s", container.name)
    except Exception as exc:  # noqa: BLE001 - triage is best-effort
        logger.warning("Triage failed for %s: %s", container.name, exc)


def _maybe_triage(
    containers: list[ContainerMetrics], last_statuses: dict[str, str]
) -> None:
    if not (settings.proactive_triage_enabled and config_from_settings()):
        return
    for c in containers:
        prev = last_statuses.get(c.id)
        if prev is not None and prev not in DOWN_STATUSES and c.status in DOWN_STATUSES:
            asyncio.create_task(_triage_container(c))


async def _maybe_digest(payload: MetricsPayload, last_day):
    if not settings.digest_enabled:
        return last_day
    cfg = config_from_settings()
    if cfg is None:
        return last_day
    now_dt = datetime.now(timezone.utc)
    if now_dt.hour == settings.digest_hour_utc and last_day != now_dt.date():
        try:
            text = await daily_digest(_summarize(payload), cfg)
            alert = Alert(
                level="info",
                kind="digest",
                target="daily",
                message=text,
                timestamp=_now_iso(),
            )
            await alert_service.dispatch([alert], time.monotonic())
            logger.info("Daily digest sent")
        except Exception as exc:  # noqa: BLE001
            logger.warning("Digest failed: %s", exc)
        return now_dt.date()
    return last_day


async def collector_loop() -> None:
    interval = settings.metrics_interval_seconds
    last_uptime = 0.0
    last_history = 0.0
    last_device = 0.0
    last_statuses: dict[str, str] = {}
    last_digest_day = None

    logger.info(
        "Collector enabled: broadcast=%s history=%s alerts=%s uptime=%s ai=%s",
        broadcast_service.enabled,
        history_service.enabled,
        bool(settings.alert_webhook_url),
        bool(settings.uptime_targets),
        settings.ai_configured,
    )

    while True:
        try:
            now = time.monotonic()

            # Self-register this agent (for multi-device tabs) every ~30s.
            if last_device == 0.0 or now - last_device >= 30:
                await device_service.register()
                last_device = now

            if settings.uptime_targets and (
                now - last_uptime >= settings.uptime_interval_seconds
                or not uptime_service.latest
            ):
                await uptime_service.refresh()
                last_uptime = now

            containers, ups, host = await asyncio.to_thread(_collect_blocking)
            payload = _assemble(containers, ups, host)

            await broadcast_service.broadcast_metrics(payload)

            alert_service.update_baselines(payload)
            alerts = alert_service.evaluate(payload)
            if alerts:
                await alert_service.dispatch(alerts, now)

            _maybe_triage(containers, last_statuses)
            last_statuses = {c.id: c.status for c in containers}

            if history_service.enabled and (
                now - last_history >= settings.history_interval_seconds
            ):
                await history_service.persist(payload)
                last_history = now

            last_digest_day = await _maybe_digest(payload, last_digest_day)

        except asyncio.CancelledError:
            raise
        except Exception as exc:  # noqa: BLE001 - never let the loop die
            logger.exception("Collector tick failed: %s", exc)

        await asyncio.sleep(interval)
