import logging
import socket

from app.config import settings
from app.models.schemas import UpsStatus

logger = logging.getLogger(__name__)


class NutService:
    """Query NUT (Network UPS Tools) upsd for power/battery status."""

    def _send_command(
        self, command: str, host: str, port: int, ups: str
    ) -> str | None:
        try:
            with socket.create_connection((host, port), timeout=2.0) as sock:
                sock.sendall(f"GET VAR {ups} {command}\n".encode())
                response = sock.recv(4096).decode("utf-8", errors="replace").strip()
                if response.startswith("VAR"):
                    parts = response.split('"')
                    if len(parts) >= 2:
                        return parts[1]
                return None
        except OSError as exc:
            logger.debug("NUT query failed (%s): %s", command, exc)
            return None

    def get_status(
        self,
        host: str | None = None,
        port: int | None = None,
        ups: str | None = None,
    ) -> UpsStatus:
        host = host or settings.nut_host
        port = port or settings.nut_port
        ups = ups or settings.nut_ups_name
        ups_status = self._send_command("ups.status", host, port, ups)
        battery = self._send_command("battery.charge", host, port, ups)
        on_battery = ups_status and "OB" in ups_status.upper()

        if ups_status is None and battery is None:
            return UpsStatus(
                connected=False,
                status="disconnected",
                error="Unable to connect to NUT server",
            )

        charge = None
        if battery is not None:
            try:
                charge = float(battery)
            except ValueError:
                charge = None

        return UpsStatus(
            connected=True,
            on_battery=bool(on_battery),
            battery_charge_percent=charge,
            status=ups_status or "unknown",
        )


nut_service = NutService()
