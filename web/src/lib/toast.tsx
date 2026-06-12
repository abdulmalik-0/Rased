import { createContext, useCallback, useContext, useState, type ReactNode } from 'react'

const Ctx = createContext<(msg: string) => void>(() => {})

export function ToastProvider({ children }: { children: ReactNode }) {
  const [msg, setMsg] = useState<string | null>(null)
  const toast = useCallback((m: string) => {
    setMsg(m)
    window.setTimeout(() => setMsg((cur) => (cur === m ? null : cur)), 2500)
  }, [])
  return (
    <Ctx.Provider value={toast}>
      {children}
      {msg && (
        <div className="fixed bottom-5 left-1/2 z-50 -translate-x-1/2 rounded-lg border border-line bg-elevated px-4 py-2 text-sm text-text-primary shadow-lg">
          {msg}
        </div>
      )}
    </Ctx.Provider>
  )
}

export const useToast = () => useContext(Ctx)
