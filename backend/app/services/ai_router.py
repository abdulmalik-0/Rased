import httpx

from app.models.schemas import AIProviderConfig
from app.services.sanitization import sanitize_text

SYSTEM_PROMPT = """You are a DevOps assistant analyzing Docker container logs.
Identify errors, warnings, root causes, and suggest actionable fixes.
Be concise. Use markdown formatting with code blocks where helpful."""


async def analyze_logs(
    logs: list[str],
    ai_config: AIProviderConfig,
    custom_prompt: str | None = None,
) -> tuple[str, str]:
    sanitized = "\n".join(sanitize_text(line) for line in logs)
    preview = sanitized[:500] + ("..." if len(sanitized) > 500 else "")

    user_content = custom_prompt or (
        "Analyze the following Docker container logs and provide insights:\n\n"
        f"```\n{sanitized}\n```"
    )

    base_url = ai_config.base_url.rstrip("/")
    if not base_url.endswith("/v1"):
        base_url = f"{base_url}/v1"

    headers = {"Content-Type": "application/json"}
    if ai_config.api_key:
        headers["Authorization"] = f"Bearer {ai_config.api_key}"

    payload = {
        "model": ai_config.model_name,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_content},
        ],
        "temperature": 0.3,
    }

    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.post(
            f"{base_url}/chat/completions",
            headers=headers,
            json=payload,
        )
        response.raise_for_status()
        data = response.json()

    analysis = data["choices"][0]["message"]["content"]
    return analysis, preview
