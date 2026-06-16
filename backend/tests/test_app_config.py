import unittest

from app.services import app_config


class TestAppConfig(unittest.TestCase):
    def setUp(self):
        app_config._cache.clear()

    def test_env_fallback_when_empty(self):
        self.assertEqual(app_config.webhook_url(), app_config.settings.alert_webhook_url)
        self.assertIsInstance(app_config.cpu_default(), float)
        self.assertEqual(app_config.ai_budget(), app_config.settings.ai_monthly_token_budget)

    def test_db_overrides_env(self):
        app_config.update(
            {
                "alert_webhook_url": "https://hooks.slack.com/x",
                "cpu_alert_percent": "55",
                "ai_monthly_token_budget": "1000",
            }
        )
        self.assertEqual(app_config.webhook_url(), "https://hooks.slack.com/x")
        self.assertEqual(app_config.cpu_default(), 55.0)
        self.assertEqual(app_config.ai_budget(), 1000)

    def test_empty_value_clears_override(self):
        app_config.update({"alert_webhook_url": "https://x"})
        app_config.update({"alert_webhook_url": ""})
        self.assertEqual(app_config.webhook_url(), app_config.settings.alert_webhook_url)


if __name__ == "__main__":
    unittest.main()
