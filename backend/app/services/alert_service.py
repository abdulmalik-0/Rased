import logging

import httpx

from app.config import settings
from app.models.schemas import Alert, MetricsPayload

logger = logging.getLogger(__name__)

# Statuses considered "down" for a container.
_DOWN_STATUSES = ("exited", "dead")

# Anomaly detection only fires above this absolute floor to avoid noise on
# idle containers whose baseline is near zero.
_ANOMALY_FLOOR_PERCENT = 25.0
_ANOMALY_FACTOR = 3.0


class AlertService:
    """Evaluate metrics against thresholds and route alerts to a webhook.

    `evaluate()` is pure (depends only on the payload + configured thresholds +
    learned baselines) so it can be unit-tested without network access.
    `dispatch()` applies per-key cooldown and posts to the webhook.
    """

    def __init__(self) -> None:
        self._last_sent: dict[str, float] = {}
        self._baselines: dict[str, float] = {}
        self.recent: list[Alert] = []

    # ---- baseline (simple EWMA per container CPU) ----
    def update_baselines(self, payload: MetricsPayload) -> None:
        for c in payload.containers:
            if c.status != "running":
                continue
            prev = self._baselines.get(c.id)
            self._baselines[c.id] = (
                c.cpu_percent if prev is None else 0.8 * prev + 0.2 * c.cpu_percent
            )

    # ---- evaluation ----
    def evaluate(self, payload: MetricsPayload) -> list[Alert]:
        ts = payload.timestamp
        alerts: list[Alert] = []

        host = payload.host
        if host.available:
            if host.cpu_percent >= settings.cpu_alert_percent:
                alerts.append(
                    Alert(
                        level="warning",
                        kind="cpu",
                        target="host",
                        value=host.cpu_percent,
                        message=f"Host CPU at {host.cpu_percent:.0f}%",
                        timestamp=ts,
                    )
                )
            if host.memory_percent >= settings.mem_alert_percent:
                alerts.append(
                    Alert(
                        level="warning",
                        kind="memory",
                        target="host",
                        value=host.memory_percent,
                        message=f"Host memory at {host.memory_percent:.0f}%",
                        timestamp=ts,
                    )
                )
            for disk in host.disks:
                if disk.percent >= settings.disk_alert_percent:
                    alerts.append(
                        Alert(
                            level="critical" if disk.percent >= 95 else "warning",
                            kind="disk",
                            target=disk.mount,
                            value=disk.percent,
                            message=f"Disk {disk.mount} at {disk.percent:.0f}% "
                            f"({disk.used_gb:.0f}/{disk.total_gb:.0f} GB)",
                            timestamp=ts,
                        )
                    )

        for c in payload.containers:
            if c.status in _DOWN_STATUSES:
                alerts.append(
                    Alert(
                        level="critical",
                        kind="container_down",
                        target=c.name,
                        message=f"Container {c.name} is {c.status}",
                        timestamp=ts,
                    )
                )
                continue
            # anomaly: CPU far above its learned baseline
            base = self._baselines.get(c.id)
            if (
                c.status == "running"
                and base is not None
                and base > 1.0
                and c.cpu_percent >= _ANOMALY_FLOOR_PERCENT
                and c.cpu_percent >= _ANOMALY_FACTOR * base
            ):
                alerts.append(
                    Alert(
                        level="warning",
                        kind="anomaly",
                        target=c.name,
                        value=c.cpu_percent,
                        message=f"{c.name} CPU {c.cpu_percent:.0f}% is "
                        f"{c.cpu_percent / base:.1f}x its baseline ({base:.0f}%)",
                        timestamp=ts,
                    )
                )

        ups = payload.ups
        if ups.connected and ups.on_battery:
            alerts.append(
                Alert(
                    level="critical",
                    kind="ups",
                    target="ups",
                    message="UPS is running on battery",
                    timestamp=ts,
                )
            )
        if (
            ups.connected
            and ups.battery_charge_percent is not None
            and ups.battery_charge_percent <= settings.battery_alert_percent
        ):
            alerts.append(
                Alert(
                    level="warning",
                    kind="ups",
                    target="battery",
                    value=ups.battery_charge_percent,
                    message=f"UPS battery low: {ups.battery_charge_percent:.0f}%",
                    timestamp=ts,
                )
            )

        for u in payload.uptime:
            if not u.up:
                alerts.append(
                    Alert(
                        level="critical",
                        kind="uptime",
                        target=u.name,
                        message=f"{u.name} is unreachable"
                        + (f" ({u.error})" if u.error else ""),
                        timestamp=ts,
                    )
                )
            if (
                u.cert_expiry_days is not None
                and u.cert_expiry_days <= settings.ssl_alert_days
            ):
                alerts.append(
                    Alert(
                        level="warning",
                        kind="ssl",
                        target=u.name,
                        value=float(u.cert_expiry_days),
                        message=f"{u.name} TLS certificate expires in "
                        f"{u.cert_expiry_days} days",
                        timestamp=ts,
                    )
                )

        return alerts

    # ---- dispatch ----
    def _key(self, alert: Alert) -> str:
        return f"{alert.kind}:{alert.target}"

    async def dispatch(self, alerts: list[Alert], now: float) -> list[Alert]:
        """Record alerts and POST new ones (past cooldown) to the webhook.

        `now` is a monotonic timestamp supplied by the caller.
        Returns the alerts that were actually sent.
        """
        sent: list[Alert] = []
        for alert in alerts:
            key = self._key(alert)
            last = self._last_sent.get(key, 0.0)
            if now - last < settings.alert_cooldown_seconds:
                continue
            self._last_sent[key] = now
            self._remember(alert)
            await self._persist(alert)
            if await self._post(alert):
                sent.append(alert)
        return sent

    def _remember(self, alert: Alert) -> None:
        self.recent.append(alert)
        if len(self.recent) > 50:
            self.recent = self.recent[-50:]

    async def _persist(self, alert: Alert) -> None:
        """Best-effort write to the Supabase alert log (service_role bypasses RLS)."""
        if not (settings.supabase_url and settings.supabase_service_role_key):
            return
        url = f"{settings.supabase_url.rstrip('/')}/rest/v1/alerts"
        headers = {
            "apikey": settings.supabase_service_role_key,
            "Authorization": f"Bearer {settings.supabase_service_role_key}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal",
        }
        row = {
            "ts": alert.timestamp,
            "host_id": settings.host_id,
            "level": alert.level,
            "kind": alert.kind,
            "target": alert.target,
            "message": alert.message,
            "value": alert.value,
        }
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                await client.post(url, headers=headers, json=row)
        except httpx.HTTPError as exc:
            logger.debug("Alert persist error: %s", exc)

    async def _post(self, alert: Alert) -> bool:
        if not settings.alert_webhook_url:
            return False
        body = {
            "text": f"[{alert.level.upper()}] {settings.host_name}: {alert.message}",
            "level": alert.level,
            "kind": alert.kind,
            "target": alert.target,
            "value": alert.value,
            "host_id": settings.host_id,
            "host_name": settings.host_name,
            "message": alert.message,
            "timestamp": alert.timestamp,
        }
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(settings.alert_webhook_url, json=body)
                if resp.status_code >= 400:
                    logger.warning(
                        "Alert webhook failed (%s): %s", resp.status_code, resp.text
                    )
                    return False
            return True
        except httpx.HTTPError as exc:
            logger.warning("Alert webhook error: %s", exc)
            return False


alert_service = AlertService()
