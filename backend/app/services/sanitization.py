import re

IP_PATTERN = re.compile(
    r"\b(?:(?:25[0-5]|2[0-4]\d|[01]?\d?\d)\.){3}"
    r"(?:25[0-5]|2[0-4]\d|[01]?\d?\d)\b"
)

EMAIL_PATTERN = re.compile(
    r"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}"
)

TOKEN_PATTERNS = [
    # OpenAI-style keys
    re.compile(r"sk-[a-zA-Z0-9\-_]{20,}"),
    # Authorization: Bearer <token>
    re.compile(r"Bearer\s+[A-Za-z0-9\-._~+/]+=*", re.IGNORECASE),
    # key/token/secret/password assignments
    re.compile(r"(?i)(api[_\-]?key|token|secret|password)\s*[:=]\s*['\"]?[^\s'\"]{8,}"),
    # JWTs
    re.compile(r"eyJ[a-zA-Z0-9\-_]+\.eyJ[a-zA-Z0-9\-_]+\.[a-zA-Z0-9\-_]+"),
    # AWS access key id
    re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    # Google API key
    re.compile(r"\bAIza[0-9A-Za-z\-_]{35,}\b"),
    # GitHub personal access / app tokens
    re.compile(r"\bgh[pousr]_[A-Za-z0-9]{36,}\b"),
    # Slack tokens
    re.compile(r"\bxox[baprs]-[0-9A-Za-z\-]{10,}\b"),
    # PEM private key headers
    re.compile(r"-----BEGIN[ A-Z]*PRIVATE KEY-----"),
]


def sanitize_text(text: str) -> str:
    """Remove sensitive data from text before sending to AI providers."""
    result = IP_PATTERN.sub("[REDACTED_IP]", text)
    result = EMAIL_PATTERN.sub("[REDACTED_EMAIL]", result)
    for pattern in TOKEN_PATTERNS:
        result = pattern.sub("[REDACTED_TOKEN]", result)
    return result


def sanitize_lines(lines: list[str]) -> list[str]:
    return [sanitize_text(line) for line in lines]
