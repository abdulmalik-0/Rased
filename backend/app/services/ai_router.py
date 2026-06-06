import httpx

from app.config import settings
from app.models.schemas import AIProviderConfig
from app.services.sanitization import sanitize_text

ANALYZE_SYSTEM_PROMPT = """You are a DevOps assistant analyzing Docker container logs.
Identify errors, warnings, root causes, and suggest actionable fixes.
Be concise. Use markdown formatting with code blocks where helpful."""

ASK_SYSTEM_PROMPT = """You are a DevOps assistant for a self-hosted server dashboard.
Answer the user's question using the provided live metrics and (optional) logs.
Be concise and practical. Use markdown. If data is insufficient, say what is missing."""

DIGEST_SYSTEM_PROMPT = """You are an SRE writing a short daily health digest for a
self-hosted server. Summarize overall status, call out anything that needs
attention (high CPU/memory/disk, containers down, UPS, expiring certs), and end
with a one-line verdict. Be concise. Use markdown."""

# Fast connect timeout so an unreachable provider fails quickly instead of
# hanging; generous read timeout so slow models can still finish.
_TIMEOUT = httpx.Timeout(connect=10.0, read=150.0, write=30.0, pool=10.0)


def _lang_directive(lang: str) -> str:
    """Force the model to answer in the UI language when it is Arabic."""
    if (lang or "").lower().startswith("ar"):
        return "\n\nIMPORTANT: Always respond in Arabic (العربية)."
    return ""


def config_from_settings() -> AIProviderConfig | None:
    """Build a server-side AI config from env (for digest / triage)."""
    if not settings.ai_configured:
        return None
    return AIProviderConfig(
        provider_type="custom",
        base_url=settings.ai_base_url,
        model_name=settings.ai_model,
        api_key=settings.ai_api_key,
    )


def _is_anthropic(ai_config: AIProviderConfig) -> bool:
    return (
        ai_config.provider_type.lower() in ("anthropic", "claude")
        or "anthropic.com" in ai_config.base_url.lower()
    )


async def _chat_openai(
    messages: list[dict], ai_config: AIProviderConfig, temperature: float
) -> str:
    base_url = ai_config.base_url.rstrip("/")
    if not base_url.endswith("/v1"):
        base_url = f"{base_url}/v1"

    headers = {"Content-Type": "application/json"}
    if ai_config.api_key:
        headers["Authorization"] = f"Bearer {ai_config.api_key}"

    payload = {
        "model": ai_config.model_name,
        "messages": messages,
        "temperature": temperature,
    }

    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        response = await client.post(
            f"{base_url}/chat/completions", headers=headers, json=payload
        )
        response.raise_for_status()
        data = response.json()

    try:
        return data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise ValueError(f"Unexpected AI response shape: {str(data)[:200]}") from exc


async def _chat_anthropic(
    messages: list[dict], ai_config: AIProviderConfig, temperature: float
) -> str:
    base_url = (ai_config.base_url or "https://api.anthropic.com").rstrip("/")
    if base_url.endswith("/v1"):
        base_url = base_url[:-3]

    system = "\n\n".join(m["content"] for m in messages if m["role"] == "system")
    convo = [m for m in messages if m["role"] != "system"]

    payload: dict = {
        "model": ai_config.model_name,
        "max_tokens": 2048,
        "temperature": temperature,
        "messages": convo,
    }
    if system:
        payload["system"] = system

    headers = {
        "x-api-key": ai_config.api_key,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
    }

    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        response = await client.post(
            f"{base_url}/v1/messages", headers=headers, json=payload
        )
        response.raise_for_status()
        data = response.json()

    try:
        parts = [b.get("text", "") for b in data["content"] if b.get("type") == "text"]
        text = "".join(parts)
        return text or data["content"][0]["text"]
    except (KeyError, IndexError, TypeError) as exc:
        raise ValueError(f"Unexpected Anthropic response: {str(data)[:200]}") from exc


async def _chat(
    messages: list[dict],
    ai_config: AIProviderConfig,
    temperature: float = 0.3,
) -> str:
    if _is_anthropic(ai_config):
        return await _chat_anthropic(messages, ai_config, temperature)
    return await _chat_openai(messages, ai_config, temperature)


async def analyze_logs(
    logs: list[str],
    ai_config: AIProviderConfig,
    custom_prompt: str | None = None,
    lang: str = "en",
) -> tuple[str, str]:
    sanitized = "\n".join(sanitize_text(line) for line in logs)
    preview = sanitized[:500] + ("..." if len(sanitized) > 500 else "")

    user_content = custom_prompt or (
        "Analyze the following Docker container logs and provide insights:\n\n"
        f"```\n{sanitized}\n```"
    )

    analysis = await _chat(
        [
            {"role": "system", "content": ANALYZE_SYSTEM_PROMPT + _lang_directive(lang)},
            {"role": "user", "content": user_content},
        ],
        ai_config,
    )
    return analysis, preview


async def ask_question(
    question: str,
    context: str,
    ai_config: AIProviderConfig,
    history: list[dict] | None = None,
    lang: str = "en",
) -> str:
    user_content = (
        f"Question:\n{question}\n\n"
        f"Live context (sanitized):\n```\n{sanitize_text(context)}\n```"
    )
    # Keep only valid prior turns (user/assistant) to maintain conversation.
    prior = [
        {"role": m["role"], "content": str(m.get("content", ""))}
        for m in (history or [])
        if m.get("role") in ("user", "assistant") and m.get("content")
    ][-20:]
    return await _chat(
        [
            {"role": "system", "content": ASK_SYSTEM_PROMPT + _lang_directive(lang)},
            *prior,
            {"role": "user", "content": user_content},
        ],
        ai_config,
    )


async def daily_digest(summary: str, ai_config: AIProviderConfig) -> str:
    return await _chat(
        [
            {"role": "system", "content": DIGEST_SYSTEM_PROMPT},
            {"role": "user", "content": f"Current server state:\n```\n{summary}\n```"},
        ],
        ai_config,
        temperature=0.4,
    )
