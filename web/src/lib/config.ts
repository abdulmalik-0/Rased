export const backendUrl = (
  import.meta.env.VITE_BACKEND_URL || 'http://localhost:8002'
).replace(/\/+$/, '')

export function wsMetricsUrl(token: string): string {
  const ws = backendUrl.replace(/^http/, 'ws')
  return `${ws}/ws/metrics?token=${encodeURIComponent(token)}`
}
