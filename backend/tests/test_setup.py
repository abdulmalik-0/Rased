import asyncio
import unittest

from app.routers.setup import agent_setup


class _FakeRequest:
    """Minimal stand-in: the endpoint only reads request.base_url."""

    base_url = "http://192.168.1.50:8002/"


class TestAgentSetup(unittest.TestCase):
    def test_payload_is_copy_paste_ready(self):
        data = asyncio.run(agent_setup(_FakeRequest(), _=None))

        # Core fields present
        for key in ("central_ingest_url", "command", "env_agent", "copy_command"):
            self.assertIn(key, data)

        central = data["central_ingest_url"]
        self.assertTrue(central.startswith("http://"))
        self.assertFalse(central.endswith("/"))  # trailing slash stripped

        # The one-line install command embeds the central URL + calls the script
        self.assertIn("install-agent.sh", data["command"])
        self.assertIn(central, data["command"])

        # The .env.agent body wires the agent back to the central node
        self.assertIn("CENTRAL_INGEST_URL=", data["env_agent"])
        self.assertIn("JWT_SECRET=", data["env_agent"])
        self.assertIn(central, data["env_agent"])


if __name__ == "__main__":
    unittest.main()
