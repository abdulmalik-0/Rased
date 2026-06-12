import { useCallback, useEffect, useRef, useState } from 'react'
import { api } from './api'
import { wsMetricsUrl } from './config'
import type { MetricsPayload } from './types'

/** Live metrics per host over WebSocket, with a REST fallback + auto-reconnect. */
export function useMetrics(token: string | null) {
  const [metrics, setMetrics] = useState<Record<string, MetricsPayload>>({})
  const wsRef = useRef<WebSocket | null>(null)

  const refresh = useCallback(async () => {
    try {
      const all = await api.getMetricsAll()
      setMetrics((prev) => {
        const next = { ...prev }
        for (const p of all) next[p.host_id] = p
        return next
      })
    } catch {
      /* ignore */
    }
  }, [])

  useEffect(() => {
    if (!token) return
    let closed = false
    let timer: ReturnType<typeof setTimeout> | undefined

    const connect = () => {
      if (closed) return
      try {
        const ws = new WebSocket(wsMetricsUrl(token))
        wsRef.current = ws
        ws.onmessage = (e) => {
          try {
            const p = JSON.parse(e.data as string) as MetricsPayload
            setMetrics((prev) => ({ ...prev, [p.host_id]: p }))
          } catch {
            /* ignore */
          }
        }
        ws.onclose = () => {
          if (!closed) timer = setTimeout(() => { refresh(); connect() }, 5000)
        }
        ws.onerror = () => ws.close()
      } catch {
        timer = setTimeout(connect, 5000)
      }
    }

    refresh()
    connect()
    return () => {
      closed = true
      if (timer) clearTimeout(timer)
      wsRef.current?.close()
    }
  }, [token, refresh])

  return { metrics, refresh }
}
