from datetime import datetime, timezone

import httpx

from app import db
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

DEPLOY_SYSTEM_PROMPT = """You are a DevOps assistant that writes ready-to-run Docker
deployment snippets. The admin will REVIEW and run them manually — you never execute
anything. Given a description of a service to run, output, using markdown fenced code
blocks:
1. A single `docker run` one-liner with sensible defaults: published ports, a named
   volume for persistent data, `--restart unless-stopped`, and common env vars.
2. An equivalent `docker-compose.yml`.
Then a short note: which URL/port to open, default credentials or first-run steps, and
any important caveats (data location, required env). Prefer well-known official images.
Be concise."""

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
) -> tuple[str, dict]:
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
        if response.status_code >= 400:
            raise ValueError(
                f"AI provider {response.status_code}: {response.text[:400]}"
            )
        data = response.json()

    try:
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise ValueError(f"Unexpected AI response shape: {str(data)[:200]}") from exc
    u = data.get("usage") or {}
    usage = {
        "prompt": int(u.get("prompt_tokens", 0) or 0),
        "completion": int(u.get("completion_tokens", 0) or 0),
    }
    return content, usage


async def _chat_anthropic(
    messages: list[dict], ai_config: AIProviderConfig, temperature: float
) -> tuple[str, dict]:
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
        if response.status_code >= 400:
            raise ValueError(
                f"AI provider {response.status_code}: {response.text[:400]}"
            )
        data = response.json()

    try:
        parts = [b.get("text", "") for b in data["content"] if b.get("type") == "text"]
        text = "".join(parts) or data["content"][0]["text"]
    except (KeyError, IndexError, TypeError) as exc:
        raise ValueError(f"Unexpected Anthropic response: {str(data)[:200]}") from exc
    u = data.get("usage") or {}
    usage = {
        "prompt": int(u.get("input_tokens", 0) or 0),
        "completion": int(u.get("output_tokens", 0) or 0),
    }
    return text, usage


def _month_start_iso() -> str:
    return (
        datetime.now(timezone.utc)
        .replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        .isoformat()
    )


async def _chat(
    messages: list[dict],
    ai_config: AIProviderConfig,
    temperature: float = 0.3,
    user_id: str = "",
    kind: str = "",
) -> str:
    # Per-user monthly token budget (central only; agents have no DB).
    if (
        settings.is_central
        and settings.ai_monthly_token_budget > 0
        and user_id
    ):
        try:
            used = await db.usage_tokens_since(user_id, _month_start_iso())
        except Exception:  # noqa: BLE001
            used = 0
        if used >= settings.ai_monthly_token_budget:
            raise ValueError("Monthly AI token budget exceeded")

    if _is_anthropic(ai_config):
        text, usage = await _chat_anthropic(messages, ai_config, temperature)
    else:
        text, usage = await _chat_openai(messages, ai_config, temperature)

    if settings.is_central:
        await db.log_usage(
            user_id, ai_config.provider_type, ai_config.model_name, kind,
            usage["prompt"], usage["completion"],
        )
    return text


async def analyze_logs(
    logs: list[str],
    ai_config: AIProviderConfig,
    custom_prompt: str | None = None,
    lang: str = "en",
    user_id: str = "",
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
        user_id=user_id,
        kind="analyze",
    )
    return analysis, preview


async def ask_question(
    question: str,
    context: str,
    ai_config: AIProviderConfig,
    history: list[dict] | None = None,
    lang: str = "en",
    user_id: str = "",
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
        user_id=user_id,
        kind="ask",
    )


async def suggest_deploy(
    description: str, ai_config: AIProviderConfig, lang: str = "en", user_id: str = ""
) -> str:
    """Suggest (not execute) a docker run / compose for the requested service."""
    user_content = (
        "Suggest how to deploy this service with Docker. I (an admin) will review "
        f"and run it myself:\n\n{description.strip()}"
    )
    return await _chat(
        [
            {"role": "system", "content": DEPLOY_SYSTEM_PROMPT + _lang_directive(lang)},
            {"role": "user", "content": user_content},
        ],
        ai_config,
        temperature=0.2,
        user_id=user_id,
        kind="deploy",
    )


DEPLOY_PLAN_PROMPT = """You convert a service request into a STRUCTURED Docker plan.
Return ONLY a JSON object (no markdown, no prose, no code fences) with exactly this shape:
{
  "image": "owner/image:tag",
  "name": "container-name",
  "ports": [{"host": 8080, "container": 80}],
  "volumes": [{"host": "named_volume", "container": "/data"}],
  "env": {"KEY": "value"},
  "restart": "unless-stopped",
  "notes": "one short line: which URL/port to open and any first-run note"
}
Use a well-known official image, sensible host ports (NEVER 8002 or 8082), a named
volume for persistent data, and only essential env vars. Output JSON only."""


def _extract_json(text: str) -> dict:
    import json
    import re

    t = re.sub(r"```(?:json)?", "", text).strip().strip("`").strip()
    start, end = t.find("{"), t.rfind("}")
    if start != -1 and end != -1:
        t = t[start : end + 1]
    try:
        data = json.loads(t)
    except Exception as exc:  # noqa: BLE001
        raise ValueError(f"AI did not return valid JSON: {text[:200]}") from exc
    if not isinstance(data, dict):
        raise ValueError("AI plan was not a JSON object")
    return data


async def plan_deploy(
    description: str, ai_config: AIProviderConfig, lang: str = "en", user_id: str = ""
) -> dict:
    """Ask the AI for a STRUCTURED docker plan (for review + one-click install)."""
    raw = await _chat(
        [
            {"role": "system", "content": DEPLOY_PLAN_PROMPT + _lang_directive(lang)},
            {"role": "user", "content": f"Service to deploy: {description.strip()}"},
        ],
        ai_config,
        temperature=0.1,
        user_id=user_id,
        kind="deploy",
    )
    return _extract_json(raw)


async def daily_digest(summary: str, ai_config: AIProviderConfig) -> str:
    return await _chat(
        [
            {"role": "system", "content": DIGEST_SYSTEM_PROMPT},
            {"role": "user", "content": f"Current server state:\n```\n{summary}\n```"},
        ],
        ai_config,
        temperature=0.4,
        kind="digest",
    )
