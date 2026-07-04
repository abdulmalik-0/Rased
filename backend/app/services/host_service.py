import logging
import os
import time

from app.models.schemas import DiskUsage, HostStats, ProcInfo, Temp

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

    def __init__(self) -> None:
        # Per-pid cumulative CPU seconds from the previous tick, so we can derive
        # each process's CPU% without a blocking sampling interval.
        self._proc_cpu: dict[int, tuple[float, float]] = {}

    def top_processes(self, limit: int = 5) -> list[ProcInfo]:
        """Busiest processes by CPU% (top-style, relative to one core), with RSS.
        CPU% is 0 on the very first tick (no baseline yet)."""
        now = time.monotonic()
        rows: list[tuple[float, float, int, str]] = []
        cur: dict[int, tuple[float, float]] = {}
        for p in psutil.process_iter(["pid", "name", "memory_info", "cpu_times"]):
            try:
                info = p.info
                pid = info["pid"]
                ct = info["cpu_times"]
                cpu_sec = (ct.user + ct.system) if ct else 0.0
                cur[pid] = (cpu_sec, now)
                cpu_pct = 0.0
                prev = self._proc_cpu.get(pid)
                if prev and now > prev[1]:
                    cpu_pct = max(0.0, (cpu_sec - prev[0]) / (now - prev[1]) * 100.0)
                mi = info["memory_info"]
                mem_mb = (mi.rss / (1024 * 1024)) if mi else 0.0
                rows.append((cpu_pct, mem_mb, pid, (info["name"] or "?")[:40]))
            except (psutil.NoSuchProcess, psutil.AccessDenied, KeyError):
                continue
        self._proc_cpu = cur  # replace wholesale — also prunes dead pids
        rows.sort(key=lambda r: (r[0], r[1]), reverse=True)
        return [
            ProcInfo(pid=pid, name=name, cpu_percent=round(c, 1), memory_mb=round(m, 1))
            for (c, m, pid, name) in rows[:limit]
        ]

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
                uptime = round(time.time() - psutil.boot_time(), 0)
            except Exception:  # pragma: no cover
                pass

            try:
                top = self.top_processes(5)
            except Exception as exc:  # noqa: BLE001 - never break stats over this
                logger.debug("top_processes failed: %s", exc)
                top = []

            temps: list[Temp] = []
            try:
                sensors = psutil.sensors_temperatures()  # Linux only
                for chip, entries in sensors.items():
                    for e in entries:
                        if e.current is None:
                            continue
                        label = e.label or chip
                        temps.append(
                            Temp(
                                label=label,
                                current=round(e.current, 1),
                                high=round(e.high, 1) if e.high else None,
                            )
                        )
            except (AttributeError, OSError, NotImplementedError):
                pass  # not available (Windows / no sensors / inside container)

            return HostStats(
                available=True,
                cpu_percent=round(cpu, 1),
                cpu_cores=psutil.cpu_count(logical=True) or 0,
                memory_used_mb=round(vm.used / (1024**2), 1),
                memory_total_mb=round(vm.total / (1024**2), 1),
                memory_percent=round(vm.percent, 1),
                disks=disks,
                temperatures=temps,
                top_processes=top,
                load_avg_1m=load_1m,
                uptime_seconds=uptime,
            )
        except Exception as exc:  # pragma: no cover - defensive
            logger.warning("Host metrics collection failed: %s", exc)
            return HostStats(available=False, error=str(exc))


host_service = HostService()
