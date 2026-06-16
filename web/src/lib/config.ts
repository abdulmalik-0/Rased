// Backend URL resolution order:
// 1) window.__RASED_BACKEND__  — injected at RUNTIME by /config.js (shipped image),
//    so one prebuilt UI image works for any server.
// 2) VITE_BACKEND_URL          — baked at build time (local builds).
// 3) localhost fallback.
declare global {
  interface Window {
    __RASED_BACKEND__?: string
  }
}

const runtime =
  typeof window !== 'undefined' && typeof window.__RASED_BACKEND__ === 'string'
    ? window.__RASED_BACKEND__
    : ''

const chosen = runtime.startsWith('http')
  ? runtime
  : import.meta.env.VITE_BACKEND_URL || 'http://localhost:8002'

export const backendUrl = chosen.replace(/\/+$/, '')

export function wsMetricsUrl(token: string): string {
  const ws = backendUrl.replace(/^http/, 'ws')
  return `${ws}/ws/metrics?token=${encodeURIComponent(token)}`
}
