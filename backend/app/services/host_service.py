import logging
import os

from app.models.schemas import DiskUsage, HostStats

logger = logging.getLogger(__name__)

try:
    import psutil  # type: ignore

    _PSUTIL_AVAILABLE = True
except Exception as exc:  # pragma: no cover - import guard
    psutil = None  # type: ignore
    _PSUTIL_AVAILABLE = False
    logger.warning("psutil unavailable, host metrics disabled: %s", exc)


class HostService:
    """Collect host-level metrics (CPU, memory, disk, load, uptime).

    Degrades gracefully to an unavailable HostStats when psutil is missing
    (e.g. running outside a host with the package installed).
    """

    def get_stats(self) -> HostStats:
        if not _PSUTIL_AVAILABLE:
            return HostStats(available=False, error="psutil not installed")

        try:
            cpu = psutil.cpu_percent(interval=None)
            vm = psutil.virtual_memory()

            # Disk: always include '/' (inside a container its overlay reflects
            # the host's backing filesystem). Skip Docker's single-file bind
            # mounts (/etc/resolv.conf, /etc/hostname, /etc/hosts) and pseudo
            # mounts, and de-duplicate filesystems that report identical usage.
            disks: list[DiskUsage] = []
            seen: set[tuple[int, int]] = set()
            skip_prefixes = ("/proc", "/sys", "/dev", "/run", "/etc", "/var/lib/docker")
            mountpoints = ["/"] + [
                p.mountpoint for p in psutil.disk_partitions(all=False)
            ]
            for mp in mountpoints:
                if mp != "/" and (
                    not os.path.isdir(mp)
                    or any(mp == p or mp.startswith(p + "/") for p in skip_prefixes)
                ):
                    continue
                try:
                    usage = psutil.disk_usage(mp)
                except (PermissionError, OSError, FileNotFoundError):
                    continue
                key = (int(usage.total), int(usage.used))
                if key in seen:
                    continue
                seen.add(key)
                disks.append(
                    DiskUsage(
                        mount=mp,
                        used_gb=round(usage.used / (1024**3), 2),
                        total_gb=round(usage.total / (1024**3), 2),
                        percent=round(usage.percent, 1),
                    )
                )

            load_1m = None
            try:
                load_1m = round(psutil.getloadavg()[0], 2)
            except (AttributeError, OSError):
                # getloadavg is not available on all platforms (e.g. Windows < 3.x)
                pass

            uptime = None
            try:
                import time

                uptime = round(time.time() - psutil.boot_time(), 0)
            except Exception:  # pragma: no cover
                pass

            return HostStats(
                available=True,
                cpu_percent=round(cpu, 1),
                cpu_cores=psutil.cpu_count(logical=True) or 0,
                memory_used_mb=round(vm.used / (1024**2), 1),
                memory_total_mb=round(vm.total / (1024**2), 1),
                memory_percent=round(vm.percent, 1),
                disks=disks,
                load_avg_1m=load_1m,
                uptime_seconds=uptime,
            )
        except Exception as exc:  # pragma: no cover - defensive
            logger.warning("Host metrics collection failed: %s", exc)
            return HostStats(available=False, error=str(exc))


host_service = HostService()
