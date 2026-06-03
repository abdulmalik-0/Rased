import re

IP_PATTERN = re.compile(
    r"\b(?:(?:25[0-5]|2[0-4]\d|[01]?\d?\d)\.){3}"
    r"(?:25[0-5]|2[0-4]\d|[01]?\d?\d)\b"
)

EMAIL_PATTERN = re.compile(
    r"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}"
)

TOKEN_PATTERNS = [
    re.compile(r"sk-[a-zA-Z0-9]{20,}"),
    re.compile(r"Bearer\s+[A-Za-z0-9\-._~+/]+=*", re.IGNORECASE),
    re.compile(r"(?i)(api[_\-]?key|token|secret|password)\s*[:=]\s*['\"]?[^\s'\"]{8,}"),
    re.compile(r"eyJ[a-zA-Z0-9\-_]+\.eyJ[a-zA-Z0-9\-_]+\.[a-zA-Z0-9\-_]+"),
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
