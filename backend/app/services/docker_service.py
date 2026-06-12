import logging

import docker
from docker.errors import DockerException

from app.models.schemas import ContainerMetrics

logger = logging.getLogger(__name__)

ALLOWED_ACTIONS = ("restart", "stop", "start")


class DockerService:
    def __init__(self) -> None:
        self._client: docker.DockerClient | None = None

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

    def run_container(self, spec: dict) -> dict:
        """Create + start a container from a reviewed, structured spec — using the
        Docker SDK directly (no shell, no string eval). Admin-gated upstream."""
        image = str(spec.get("image") or "").strip()
        if not image:
            raise ValueError("image is required")
        name = str(spec.get("name") or "").strip() or None

        ports: dict[str, int] = {}
        for p in spec.get("ports") or []:
            cport = str(p.get("container") or "").strip()
            hport = p.get("host")
            if cport and hport:
                ports[f"{cport}/tcp"] = int(hport)

        volumes: dict[str, dict] = {}
        for v in spec.get("volumes") or []:
            vh = str(v.get("host") or "").strip()
            vc = str(v.get("container") or "").strip()
            if vh and vc:
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
        container.reload()
        return {
            "id": container.short_id,
            "name": container.name,
            "status": container.status,
        }

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
        containers: list[ContainerMetrics] = []
        try:
            for container in self.client.containers.list(all=True):
                cpu_percent = 0.0
                mem_usage, mem_limit, mem_percent = 0.0, 0.0, 0.0
                if container.status == "running":
                    try:
                        stats = container.stats(stream=False)
                        cpu_percent = round(self._calc_cpu_percent(stats), 2)
                        mem_usage, mem_limit, mem_percent = self._calc_memory(stats)
                        mem_usage = round(mem_usage, 2)
                        mem_limit = round(mem_limit, 2)
                        mem_percent = round(mem_percent, 2)
                    except DockerException as exc:
                        logger.warning("Stats unavailable for %s: %s", container.id, exc)

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

                containers.append(
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
                    )
                )
        except DockerException as exc:
            logger.error("Docker connection failed: %s", exc)

        return containers


docker_service = DockerService()
