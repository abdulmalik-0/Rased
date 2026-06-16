import unittest

from app.services.docker_service import _is_unsafe_bind


class TestBindPolicy(unittest.TestCase):
    def test_named_volume_and_appdata_allowed(self):
        for p in ("myvol", "n8n_data", "/opt/appdata", "/srv/jellyfin"):
            self.assertFalse(_is_unsafe_bind(p), p)

    def test_sensitive_paths_denied(self):
        for p in (
            "/",
            "/etc",
            "/etc/passwd",
            "/var/run/docker.sock",
            "/run/docker.sock",
            "/proc",
            "/sys/kernel",
            "/root/.ssh",
            "/boot",
            "/dev/sda",
        ):
            self.assertTrue(_is_unsafe_bind(p), p)


if __name__ == "__main__":
    unittest.main()
