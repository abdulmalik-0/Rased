import asyncio
import logging

import httpx

from app import db
from app.config import settings
from app.models.schemas import Alert, MetricsPayload

logger = logging.getLogger(__name__)

_DOWN_STATUSES = ("exited", "dead")
_ANOMALY_FLOOR_PERCENT = 25.0
_ANOMALY_FACTOR = 3.0


class AlertService:
    """Evaluate metrics vs thresholds and route alerts to a webhook + the DB.

    Keyed per host so multiple machines don't suppress each other's alerts.
    """

    def __init__(self) -> None:
        self._last_sent: dict[str, float] = {}
        self._baselines: dict[str, float] = {}
        self.recent: dict[str, list[Alert]] = {}

    def recent_for(self, host_id: str) -> list[Alert]:
        return self.recent.get(host_id, [])[-10:]

    def update_baselines(self, payload: MetricsPayload) -> None:
        for c in payload.containers:
            if c.status != "running":
                continue
            key = f"{payload.host_id}:{c.id}"
            prev = self._baselines.get(key)
            self._baselines[key] = (
                c.cpu_percent if prev is None else 0.8 * prev + 0.2 * c.cpu_percent
            )

    def evaluate(self, payload: MetricsPayload) -> list[Alert]:
        ts = payload.timestamp
        alerts: list[Alert] = []
        host = payload.host

        if host.available:
            if host.cpu_percent >= settings.cpu_alert_percent:
                alerts.append(Alert(level="warning", kind="cpu", target="host",
                                    value=host.cpu_percent,
                                    message=f"Host CPU at {host.cpu_percent:.0f}%",
                                    timestamp=ts))
            if host.memory_percent >= settings.mem_alert_percent:
                alerts.append(Alert(level="warning", kind="memory", target="host",
                                    value=host.memory_percent,
                                    message=f"Host memory at {host.memory_percent:.0f}%",
                                    timestamp=ts))
            for disk in host.disks:
                if disk.percent >= settings.disk_alert_percent:
                    alerts.append(Alert(
                        level="critical" if disk.percent >= 95 else "warning",
                        kind="disk", target=disk.mount, value=disk.percent,
                        message=f"Disk {disk.mount} at {disk.percent:.0f}%",
                        timestamp=ts))

        for c in payload.containers:
            if c.status in _DOWN_STATUSES:
                alerts.append(Alert(level="critical", kind="container_down",
                                    target=c.name,
                                    message=f"Container {c.name} is {c.status}",
                                    timestamp=ts))
                continue
            base = self._baselines.get(f"{payload.host_id}:{c.id}")
            if (
                c.status == "running"
                and base is not None
                and base > 1.0
                and c.cpu_percent >= _ANOMALY_FLOOR_PERCENT
                and c.cpu_percent >= _ANOMALY_FACTOR * base
            ):
                alerts.append(Alert(level="warning", kind="anomaly", target=c.name,
                                    value=c.cpu_percent,
                                    message=f"{c.name} CPU {c.cpu_percent:.0f}% is "
                                    f"{c.cpu_percent / base:.1f}x its baseline",
                                    timestamp=ts))

        ups = payload.ups
        if ups.connected and ups.on_battery:
            alerts.append(Alert(level="critical", kind="ups", target="ups",
                                message="UPS is running on battery", timestamp=ts))
        if (ups.connected and ups.battery_charge_percent is not None
                and ups.battery_charge_percent <= settings.battery_alert_percent):
            alerts.append(Alert(level="warning", kind="ups", target="battery",
                                value=ups.battery_charge_percent,
                                message=f"UPS battery low: {ups.battery_charge_percent:.0f}%",
                                timestamp=ts))

        for u in payload.uptime:
            if not u.up:
                alerts.append(Alert(level="critical", kind="uptime", target=u.name,
                                    message=f"{u.name} is unreachable"
                                    + (f" ({u.error})" if u.error else ""),
                                    timestamp=ts))
            if u.cert_expiry_days is not None and u.cert_expiry_days <= settings.ssl_alert_days:
                alerts.append(Alert(level="warning", kind="ssl", target=u.name,
                                    value=float(u.cert_expiry_days),
                                    message=f"{u.name} TLS cert expires in {u.cert_expiry_days} days",
                                    timestamp=ts))

        return alerts

    async def dispatch(self, alerts: list[Alert], now: float, host_id: str) -> list[Alert]:
        sent: list[Alert] = []
        for alert in alerts:
            key = f"{host_id}:{alert.kind}:{alert.target}"
            if now - self._last_sent.get(key, 0.0) < settings.alert_cooldown_seconds:
                continue
            self._last_sent[key] = now
            self.recent.setdefault(host_id, []).append(alert)
            self.recent[host_id] = self.recent[host_id][-50:]
            await self._persist(alert, host_id)
            if await self._post(alert, host_id):
                sent.append(alert)
        return sent

    async def _persist(self, alert: Alert, host_id: str) -> None:
        try:
            await db.insert_alert(alert.timestamp, host_id, alert.level,
                                  alert.kind, alert.target, alert.message, alert.value)
        except Exception as exc:  # noqa: BLE001
            logger.debug("Alert persist error: %s", exc)

    async def _post(self, alert: Alert, host_id: str) -> bool:
        if not settings.alert_webhook_url:
            return False
        body = {
            "text": f"[{alert.level.upper()}] {host_id}: {alert.message}",
            "level": alert.level, "kind": alert.kind, "target": alert.target,
            "value": alert.value, "host_id": host_id, "message": alert.message,
            "timestamp": alert.timestamp,
        }
        # Retry with backoff so a momentary webhook outage doesn't drop the alert.
        delays = (0.0, 1.0, 3.0)
        async with httpx.AsyncClient(timeout=10.0) as client:
            for attempt, delay in enumerate(delays, start=1):
                if delay:
                    await asyncio.sleep(delay)
                try:
                    resp = await client.post(settings.alert_webhook_url, json=body)
                    if resp.status_code < 400:
                        return True
                    logger.warning(
                        "Alert webhook HTTP %s (attempt %s)", resp.status_code, attempt
                    )
                except httpx.HTTPError as exc:
                    logger.warning("Alert webhook error (attempt %s): %s", attempt, exc)
        return False


alert_service = AlertService()
