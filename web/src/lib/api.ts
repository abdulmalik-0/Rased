import { backendUrl } from './config'
import type {
  AIProviderConfig,
  AuthSession,
  DeployPlan,
  DeployResult,
  Device,
  MetricsPayload,
} from './types'

let authToken: string | null = null
export function setAuthToken(t: string | null) {
  authToken = t
}

export function decodeJwt(token: string): Record<string, unknown> {
  try {
    const part = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')
    return JSON.parse(decodeURIComponent(escape(atob(part))))
  } catch {
    return {}
  }
}

function headers(json = false): Record<string, string> {
  const h: Record<string, string> = {}
  if (json) h['Content-Type'] = 'application/json'
  if (authToken) h['Authorization'] = `Bearer ${authToken}`
  return h
}

async function handle(resp: Response) {
  if (!resp.ok) {
    let detail = `Request failed (${resp.status})`
    try {
      const b = await resp.json()
      if (b?.detail) detail = String(b.detail)
    } catch {
      /* ignore */
    }
    throw new Error(detail)
  }
  return resp
}

const base = (u?: string) => (u && u.length ? u.replace(/\/+$/, '') : backendUrl)

export const api = {
  // ---- auth ----
  async login(email: string, password: string): Promise<AuthSession> {
    const r = await handle(
      await fetch(`${backendUrl}/auth/login`, {
        method: 'POST',
        headers: headers(true),
        body: JSON.stringify({ email, password }),
      }),
    )
    const b = await r.json()
    return { token: b.token, email: b.email ?? email, role: b.role ?? 'viewer' }
  },

  async register(
    email: string,
    password: string,
  ): Promise<{ pending: boolean; session: AuthSession | null }> {
    const r = await handle(
      await fetch(`${backendUrl}/auth/register`, {
        method: 'POST',
        headers: headers(true),
        body: JSON.stringify({ email, password }),
      }),
    )
    const b = await r.json()
    if (b.pending || !b.token) return { pending: true, session: null }
    return {
      pending: false,
      session: { token: b.token, email: b.email ?? email, role: b.role ?? 'viewer' },
    }
  },

  // ---- metrics / devices ----
  async getMetricsAll(): Promise<MetricsPayload[]> {
    const r = await handle(
      await fetch(`${backendUrl}/metrics/all`, { headers: headers() }),
    )
    return r.json()
  },

  async getDevices(): Promise<Device[]> {
    const r = await handle(await fetch(`${backendUrl}/devices`, { headers: headers() }))
    return r.json()
  },

  async updateDevice(
    hostId: string,
    body: { display_name?: string; nut_host?: string; nut_ups_name?: string },
  ): Promise<void> {
    await handle(
      await fetch(`${backendUrl}/devices/${hostId}`, {
        method: 'PATCH',
        headers: headers(true),
        body: JSON.stringify(body),
      }),
    )
  },

  // ---- container links ----
  async getLinks(hostId: string): Promise<Record<string, string>[]> {
    const r = await handle(
      await fetch(`${backendUrl}/links?host_id=${encodeURIComponent(hostId)}`, {
        headers: headers(),
      }),
    )
    return r.json()
  },
  async setLink(hostId: string, name: string, url: string, label: string) {
    await handle(
      await fetch(`${backendUrl}/links`, {
        method: 'PUT',
        headers: headers(true),
        body: JSON.stringify({ host_id: hostId, name, url, label }),
      }),
    )
  },
  async deleteLink(hostId: string, name: string) {
    await handle(
      await fetch(
        `${backendUrl}/links?host_id=${encodeURIComponent(hostId)}&name=${encodeURIComponent(name)}`,
        { method: 'DELETE', headers: headers() },
      ),
    )
  },

  // ---- settings ----
  async getSettings(): Promise<AIProviderConfig | null> {
    const r = await handle(await fetch(`${backendUrl}/settings`, { headers: headers() }))
    const text = await r.text()
    if (!text || text === 'null') return null
    return JSON.parse(text)
  },
  async saveSettings(cfg: AIProviderConfig) {
    await handle(
      await fetch(`${backendUrl}/settings`, {
        method: 'POST',
        headers: headers(true),
        body: JSON.stringify(cfg),
      }),
    )
  },

  // ---- users ----
  async getUsers(): Promise<Record<string, unknown>[]> {
    const r = await handle(await fetch(`${backendUrl}/users`, { headers: headers() }))
    return r.json()
  },
  async patchUser(uid: string, body: { role?: string; approved?: boolean }) {
    await handle(
      await fetch(`${backendUrl}/users/${uid}`, {
        method: 'PATCH',
        headers: headers(true),
        body: JSON.stringify(body),
      }),
    )
  },

  // ---- onboarding ----
  async getAgentSetup(): Promise<Record<string, unknown>> {
    const r = await handle(
      await fetch(`${backendUrl}/setup/agent`, { headers: headers() }),
    )
    return r.json()
  },

  // ---- history ----
  async getHistory(hours: number): Promise<Record<string, unknown>[]> {
    const r = await handle(
      await fetch(`${backendUrl}/history?hours=${hours}`, { headers: headers() }),
    )
    return r.json()
  },

  // ---- chats ----
  async getChats(hostId: string): Promise<Record<string, unknown>[]> {
    const r = await handle(
      await fetch(`${backendUrl}/chats?host_id=${encodeURIComponent(hostId)}`, {
        headers: headers(),
      }),
    )
    return r.json()
  },
  async upsertChat(body: {
    id?: string | null
    host_id: string
    title: string
    messages: { role: string; content: string }[]
  }): Promise<string> {
    const r = await handle(
      await fetch(`${backendUrl}/chats`, {
        method: 'POST',
        headers: headers(true),
        body: JSON.stringify(body),
      }),
    )
    return (await r.json()).id
  },
  async deleteChat(id: string) {
    await handle(
      await fetch(`${backendUrl}/chats/${id}`, { method: 'DELETE', headers: headers() }),
    )
  },

  // ---- per-device AI / actions ----
  async analyzeLogs(opts: {
    containerId: string
    aiConfig: AIProviderConfig
    tail?: number
    lang?: string
    baseUrl?: string
  }): Promise<{ analysis: string; model_used: string }> {
    const r = await handle(
      await fetch(`${base(opts.baseUrl)}/analyze`, {
        method: 'POST',
        headers: headers(true),
        body: JSON.stringify({
          container_id: opts.containerId,
          ai_config: opts.aiConfig,
          tail: opts.tail ?? 100,
          lang: opts.lang ?? 'en',
        }),
      }),
    )
    return r.json()
  },

  async ask(opts: {
    question: string
    aiConfig: AIProviderConfig
    history?: { role: string; content: string }[]
    lang?: string
    baseUrl?: string
  }): Promise<{ answer: string; model_used: string }> {
    const r = await handle(
      await fetch(`${base(opts.baseUrl)}/ask`, {
        method: 'POST',
        headers: headers(true),
        body: JSON.stringify({
          question: opts.question,
          ai_config: opts.aiConfig,
          include_logs: true,
          history: opts.history ?? [],
          lang: opts.lang ?? 'en',
        }),
      }),
    )
    return r.json()
  },

  async suggestDeploy(opts: {
    description: string
    aiConfig: AIProviderConfig
    lang?: string
  }): Promise<string> {
    const r = await handle(
      await fetch(`${backendUrl}/deploy/suggest`, {
        method: 'POST',
        headers: headers(true),
        body: JSON.stringify({
          description: opts.description,
          ai_config: opts.aiConfig,
          lang: opts.lang ?? 'en',
        }),
      }),
    )
    return (await r.json()).suggestion ?? ''
  },

  async planDeploy(opts: {
    description: string
    aiConfig: AIProviderConfig
    lang?: string
  }): Promise<DeployPlan> {
    const r = await handle(
      await fetch(`${backendUrl}/deploy/plan`, {
        method: 'POST',
        headers: headers(true),
        body: JSON.stringify({
          description: opts.description,
          ai_config: opts.aiConfig,
          lang: opts.lang ?? 'en',
        }),
      }),
    )
    return r.json()
  },

  async runDeploy(plan: DeployPlan, baseUrl?: string): Promise<DeployResult> {
    const r = await handle(
      await fetch(`${base(baseUrl)}/deploy/run`, {
        method: 'POST',
        headers: headers(true),
        body: JSON.stringify(plan),
      }),
    )
    return r.json()
  },

  async runImage(image: string, name = '', baseUrl?: string): Promise<DeployResult> {
    const r = await handle(
      await fetch(`${base(baseUrl)}/deploy/image`, {
        method: 'POST',
        headers: headers(true),
        body: JSON.stringify({ image, name }),
      }),
    )
    return r.json()
  },

  async fetchLogs(containerId: string, tail = 200, baseUrl?: string): Promise<string[]> {
    const r = await handle(
      await fetch(`${base(baseUrl)}/logs/${containerId}?tail=${tail}`, {
        headers: headers(),
      }),
    )
    const b = await r.json()
    return (b.sanitized_lines ?? []).map(String)
  },

  async containerAction(
    containerId: string,
    action: string,
    baseUrl?: string,
  ): Promise<string> {
    const r = await handle(
      await fetch(`${base(baseUrl)}/actions/${containerId}`, {
        method: 'POST',
        headers: headers(true),
        body: JSON.stringify({ action }),
      }),
    )
    return (await r.json()).status ?? 'unknown'
  },
}
