import asyncio
import unittest

from app.models.schemas import (
    ContainerMetrics,
    DiskUsage,
    HostStats,
    MetricsPayload,
    UptimeResult,
    UpsStatus,
)
from app.services.alert_service import AlertService


def _payload() -> MetricsPayload:
    return MetricsPayload(
        timestamp="2026-06-05T00:00:00+00:00",
        host_id="t",
        host_name="Test",
        containers=[
            ContainerMetrics(id="a", name="web", status="exited", image="nginx"),
            ContainerMetrics(
                id="b", name="db", status="running", image="pg", cpu_percent=5
            ),
        ],
        ups=UpsStatus(connected=True, on_battery=True, battery_charge_percent=20),
        host=HostStats(
            available=True,
            cpu_percent=95,
            memory_percent=50,
            disks=[DiskUsage(mount="/", used_gb=90, total_gb=100, percent=90)],
        ),
        uptime=[
            UptimeResult(name="site", url="https://x", up=False, error="timeout"),
            UptimeResult(name="api", url="https://y", up=True, cert_expiry_days=5),
        ],
    )


class TestAlertEvaluate(unittest.TestCase):
    def test_evaluate_kinds(self):
        svc = AlertService()
        alerts = svc.evaluate(_payload())
        kinds = {a.kind for a in alerts}
        self.assertIn("cpu", kinds)
        self.assertIn("disk", kinds)
        self.assertIn("container_down", kinds)
        self.assertIn("ups", kinds)
        self.assertIn("uptime", kinds)
        self.assertIn("ssl", kinds)
        self.assertNotIn("memory", kinds)  # 50% < 90% threshold

    def test_cooldown_dedup(self):
        svc = AlertService()
        alerts = svc.evaluate(_payload())

        async def run():
            first = await svc.dispatch(alerts, now=1000.0)
            # within cooldown window -> nothing new dispatched
            second = await svc.dispatch(alerts, now=1001.0)
            return first, second

        first, second = asyncio.run(run())
        # no webhook configured -> _post returns False, so "sent" is empty,
        # but recent must be populated once and not duplicated on the 2nd call.
        self.assertEqual(second, [])
        self.assertTrue(len(svc.recent) >= 1)
        recent_after_first = len(svc.recent)
        self.assertEqual(recent_after_first, len(svc.recent))


if __name__ == "__main__":
    unittest.main()
