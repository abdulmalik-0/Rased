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

    def test_redacts_aws_access_key(self):
        text = "aws id AKIAIOSFODNN7EXAMPLE in config"
        result = sanitize_text(text)
        self.assertIn("[REDACTED_TOKEN]", result)
        self.assertNotIn("AKIAIOSFODNN7EXAMPLE", result)

    def test_redacts_github_token(self):
        text = "token ghp_1234567890abcdefghijklmnopqrstuvwxyz used"
        result = sanitize_text(text)
        self.assertIn("[REDACTED_TOKEN]", result)

    def test_redacts_google_api_key(self):
        text = "key AIzaSyA1234567890abcdefghijklmnopqrstuvw here"
        result = sanitize_text(text)
        self.assertIn("[REDACTED_TOKEN]", result)

    def test_redacts_pem_header(self):
        text = "-----BEGIN RSA PRIVATE KEY-----"
        result = sanitize_text(text)
        self.assertIn("[REDACTED_TOKEN]", result)

    def test_keeps_normal_text(self):
        text = "Container started successfully on port 8080"
        self.assertEqual(sanitize_text(text), text)


if __name__ == "__main__":
    unittest.main()
