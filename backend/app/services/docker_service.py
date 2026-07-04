import logging
import time
from concurrent.futures import ThreadPoolExecutor

import docker
from docker.errors import DockerException

from app.models.schemas import ContainerMetrics

logger = logging.getLogger(__name__)

ALLOWED_ACTIONS = ("restart", "stop", "start")

# Host paths an AI-planned container must never bind-mount (defense beyond review).
_DENY_BIND_PREFIXES = (
    "/etc", "/var/run", "/run", "/proc", "/sys", "/root", "/boot", "/dev",
)


def _is_unsafe_bind(host_path: str) -> bool:
    p = host_path.strip()
    if not p.startswith("/"):
        return False  # a named volume — safe
    if "docker.sock" in p or p == "/":
        return True
    return any(p == d or p.startswith(d + "/") for d in _DENY_BIND_PREFIXES)


class DockerService:
    def __init__(self) -> None:
        self._client: docker.DockerClient | None = None
        # Per-container cumulative I/O counters from the previous tick, so we can
        # derive live rates: {cid: (rx, tx, blk_read, blk_write, monotonic_ts)}.
        self._io_prev: dict[str, tuple[float, float, float, float, float]] = {}

    @property
    def client(self) -> docker.DockerClient:
        if self._client is None:
            self._client = docker.from_env()
        return self._client

    def get_container_logs(self, container_id: str, tail: int = 100) -> list[str]:
        container = self.client.containers.get(container_id)
        raw = container.logs(tail=tail, timestamps=True)
        text = raw.decode("utf-8", errors="replace")
        return [line for line in text.splitlines() if line.strip()]

    def container_action(self, container_id: str, action: str) -> str:
        """Perform a lifecycle action (restart/stop/start) on a container."""
        if action not in ALLOWED_ACTIONS:
            raise ValueError(f"Unsupported action '{action}'")
        container = self.client.containers.get(container_id)
        getattr(container, action)()
        container.reload()
        return container.status

    # Ports already published by any Docker container (running or stopped).
    def _used_host_ports(self) -> set[int]:
        used: set[int] = set()
        try:
            for c in self.client.containers.list(all=True):
                attrs = c.attrs or {}
                groups = [
                    (attrs.get("NetworkSettings", {}) or {}).get("Ports", {}) or {},
                    (attrs.get("HostConfig", {}) or {}).get("PortBindings", {}) or {},
                ]
                for ports in groups:
                    for binds in ports.values():
                        for b in binds or []:
                            hp = b.get("HostPort")
                            if hp and str(hp).isdigit():
                                used.add(int(hp))
        except DockerException:
            pass
        return used

    # Next free host port at/above `want`, skipping used + Rased's own ports.
    def _free_port(self, want: int, used: set[int]) -> int:
        reserved = {8002, 8082}
        p = want if want > 0 else 8080
        while p in used or p in reserved:
            p += 1
            if p > 65000:
                p = 1025
        used.add(p)
        return p

    def _result(self, container, ports: dict[str, int]) -> dict:
        container.reload()
        return {
            "id": container.short_id,
            "name": container.name,
            "status": container.status,
            "ports": [
                {"host": hp, "container": int(cp.split("/")[0])}
                for cp, hp in ports.items()
            ],
        }

    def run_container(self, spec: dict) -> dict:
        """Create + start a container from a reviewed, structured spec — using the
        Docker SDK directly (no shell). Auto-reassigns any taken host port."""
        image = str(spec.get("image") or "").strip()
        if not image:
            raise ValueError("image is required")
        name = str(spec.get("name") or "").strip() or None

        used = self._used_host_ports()
        ports: dict[str, int] = {}
        for p in spec.get("ports") or []:
            cport = str(p.get("container") or "").strip()
            hport = p.get("host")
            if cport and hport:
                ports[f"{cport}/tcp"] = self._free_port(int(hport), used)

        volumes: dict[str, dict] = {}
        for v in spec.get("volumes") or []:
            vh = str(v.get("host") or "").strip()
            vc = str(v.get("container") or "").strip()
            if vh and vc:
                if _is_unsafe_bind(vh):
                    raise ValueError(f"Refusing unsafe host bind mount: {vh}")
                volumes[vh] = {"bind": vc, "mode": "rw"}

        env = {str(k): str(val) for k, val in (spec.get("env") or {}).items()}
        restart = str(spec.get("restart") or "unless-stopped").strip()

        container = self.client.containers.run(
            image,
            name=name,
            detach=True,
            ports=ports or None,
            volumes=volumes or None,
            environment=env or None,
            restart_policy={"Name": restart} if restart else None,
        )
        return self._result(container, ports)

    def run_image(self, image: str, name: str = "") -> dict:
        """Pull an image and run it, auto-publishing its EXPOSEd ports to free host
        ports. The "just give me an image" path."""
        image = image.strip()
        if not image:
            raise ValueError("image is required")
        img = self.client.images.pull(image)
        exposed = (img.attrs.get("Config", {}) or {}).get("ExposedPorts", {}) or {}

        name = name.strip() or image.rsplit("/", 1)[-1].split(":")[0]
        used = self._used_host_ports()
        ports: dict[str, int] = {}
        for cport in exposed:  # e.g. "80/tcp"
            num = int(str(cport).split("/")[0])
            ports[cport] = self._free_port(num, used)

        container = self.client.containers.run(
            image,
            name=name or None,
            detach=True,
            ports=ports or None,
            restart_policy={"Name": "unless-stopped"},
        )
        return self._result(container, ports)

    def _calc_cpu_percent(self, stats: dict) -> float:
        try:
            cpu_delta = (
                stats["cpu_stats"]["cpu_usage"]["total_usage"]
                - stats["precpu_stats"]["cpu_usage"]["total_usage"]
            )
            system_delta = (
                stats["cpu_stats"]["system_cpu_usage"]
                - stats["precpu_stats"]["system_cpu_usage"]
            )
            online_cpus = stats["cpu_stats"].get(
                "online_cpus",
                len(stats["cpu_stats"]["cpu_usage"].get("percpu_usage", [1])),
            )
            if system_delta > 0 and cpu_delta > 0:
                return (cpu_delta / system_delta) * online_cpus * 100.0
        except (KeyError, TypeError, ZeroDivisionError):
            pass
        return 0.0

    @staticmethod
    def _sum_io(stats: dict) -> tuple[float, float, float, float]:
        """Cumulative (rx, tx, blk_read, blk_write) bytes from a stats sample.
        Block I/O is empty on cgroup v2 hosts — network still works there."""
        rx = tx = 0.0
        for iface in (stats.get("networks") or {}).values():
            rx += iface.get("rx_bytes", 0) or 0
            tx += iface.get("tx_bytes", 0) or 0
        read = write = 0.0
        for e in (stats.get("blkio_stats") or {}).get("io_service_bytes_recursive") or []:
            op = (e.get("op") or "").lower()
            val = e.get("value", 0) or 0
            if op == "read":
                read += val
            elif op == "write":
                write += val
        return rx, tx, read, write

    def _io_rates(self, cid: str, stats: dict) -> tuple[float, float, float, float]:
        rx, tx, read, write = self._sum_io(stats)
        now = time.monotonic()
        prev = self._io_prev.get(cid)
        self._io_prev[cid] = (rx, tx, read, write, now)
        if not prev:
            return 0.0, 0.0, 0.0, 0.0  # first sample — no rate yet
        dt = now - prev[4]
        if dt <= 0:
            return 0.0, 0.0, 0.0, 0.0

        def rate(cur: float, old: float) -> float:
            d = cur - old
            return round(d / dt, 1) if d > 0 else 0.0  # counters only rise

        return rate(rx, prev[0]), rate(tx, prev[1]), rate(read, prev[2]), rate(write, prev[3])

    def _calc_memory(self, stats: dict) -> tuple[float, float, float]:
        try:
            usage = stats["memory_stats"].get("usage", 0)
            limit = stats["memory_stats"].get("limit", 1)
            usage_mb = usage / (1024 * 1024)
            limit_mb = limit / (1024 * 1024)
            percent = (usage / limit * 100) if limit else 0.0
            return usage_mb, limit_mb, percent
        except (KeyError, TypeError, ZeroDivisionError):
            return 0.0, 0.0, 0.0

    def list_container_metrics(self) -> list[ContainerMetrics]:
        try:
            containers = self.client.containers.list(all=True)
        except DockerException as exc:
            logger.error("Docker connection failed: %s", exc)
            return []

        # Each stats() call blocks ~1-2s; fetch running containers concurrently so a
        # 20-container host doesn't take 20-40s per collector tick.
        def _stats(c):
            try:
                return c.id, c.stats(stream=False)
            except DockerException as exc:
                logger.warning("Stats unavailable for %s: %s", c.id, exc)
                return c.id, None

        running = [c for c in containers if c.status == "running"]
        stats_by_id: dict[str, dict] = {}
        if running:
            with ThreadPoolExecutor(max_workers=min(8, len(running))) as pool:
                for cid, st in pool.map(_stats, running):
                    if st is not None:
                        stats_by_id[cid] = st

        result: list[ContainerMetrics] = []
        for container in containers:
            cpu_percent = 0.0
            mem_usage, mem_limit, mem_percent = 0.0, 0.0, 0.0
            net_rx = net_tx = blk_r = blk_w = 0.0
            st = stats_by_id.get(container.id)
            if st is not None:
                cpu_percent = round(self._calc_cpu_percent(st), 2)
                mem_usage, mem_limit, mem_percent = self._calc_memory(st)
                mem_usage = round(mem_usage, 2)
                mem_limit = round(mem_limit, 2)
                mem_percent = round(mem_percent, 2)
                net_rx, net_tx, blk_r, blk_w = self._io_rates(container.id, st)

            tags = container.image.tags if container.image else []
            ports: list[str] = []
            try:
                for _cport, bindings in (container.ports or {}).items():
                    for b in bindings or []:
                        hp = b.get("HostPort")
                        if hp and hp not in ports:
                            ports.append(hp)
            except (AttributeError, TypeError):
                pass

            result.append(
                ContainerMetrics(
                    id=container.id[:12],
                    name=container.name.lstrip("/"),
                    status=container.status,
                    image=tags[0] if tags else "unknown",
                    cpu_percent=cpu_percent,
                    memory_usage_mb=mem_usage,
                    memory_limit_mb=mem_limit,
                    memory_percent=mem_percent,
                    restart_count=int(container.attrs.get("RestartCount", 0) or 0),
                    ports=sorted(ports, key=lambda x: int(x) if x.isdigit() else 0),
                    net_rx_bytes_ps=net_rx,
                    net_tx_bytes_ps=net_tx,
                    blk_read_bytes_ps=blk_r,
                    blk_write_bytes_ps=blk_w,
                )
            )

        # Forget rate state for containers that no longer exist.
        live_ids = {c.id for c in containers}
        for cid in list(self._io_prev):
            if cid not in live_ids:
                self._io_prev.pop(cid, None)
        return result


docker_service = DockerService()
