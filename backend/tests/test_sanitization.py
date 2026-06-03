import unittest

from app.services.sanitization import sanitize_text


class TestSanitization(unittest.TestCase):
    def test_redacts_ip(self):
        text = "Connection from 192.168.1.100 failed"
        result = sanitize_text(text)
        self.assertIn("[REDACTED_IP]", result)
        self.assertNotIn("192.168.1.100", result)

    def test_redacts_email(self):
        text = "User admin@example.com logged in"
        result = sanitize_text(text)
        self.assertIn("[REDACTED_EMAIL]", result)
        self.assertNotIn("admin@example.com", result)

    def test_redacts_openai_key(self):
        text = "Using key sk-abcdefghijklmnopqrstuvwxyz123456"
        result = sanitize_text(text)
        self.assertIn("[REDACTED_TOKEN]", result)

    def test_redacts_bearer_token(self):
        text = "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        result = sanitize_text(text)
        self.assertIn("[REDACTED_TOKEN]", result)


if __name__ == "__main__":
    unittest.main()
