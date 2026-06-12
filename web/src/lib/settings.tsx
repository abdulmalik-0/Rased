import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from 'react'
import { api } from './api'
import type { AIProviderConfig } from './types'

interface SettingsCtx {
  config: AIProviderConfig | null
  loading: boolean
  reload: () => Promise<void>
  save: (c: AIProviderConfig) => Promise<void>
}
const Ctx = createContext<SettingsCtx | null>(null)

export function SettingsProvider({ children }: { children: ReactNode }) {
  const [config, setConfig] = useState<AIProviderConfig | null>(null)
  const [loading, setLoading] = useState(true)

  const reload = useCallback(async () => {
    setLoading(true)
    try {
      setConfig(await api.getSettings())
    } catch {
      setConfig(null)
    } finally {
      setLoading(false)
    }
  }, [])

  const save = useCallback(
    async (c: AIProviderConfig) => {
      await api.saveSettings(c)
      await reload()
    },
    [reload],
  )

  useEffect(() => {
    reload()
  }, [reload])

  return (
    <Ctx.Provider value={{ config, loading, reload, save }}>{children}</Ctx.Provider>
  )
}

export function useSettings() {
  const c = useContext(Ctx)
  if (!c) throw new Error('useSettings outside provider')
  return c
}
