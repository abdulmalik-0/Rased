import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import type { Theme } from './types'

interface ThemeCtx {
  theme: Theme
  toggle: () => void
  set: (t: Theme) => void
}
const Ctx = createContext<ThemeCtx | null>(null)

function apply(theme: Theme) {
  document.documentElement.classList.toggle('dark', theme === 'dark')
}

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setTheme] = useState<Theme>(
    () => (localStorage.getItem('theme') as Theme) || 'dark',
  )
  useEffect(() => {
    apply(theme)
    localStorage.setItem('theme', theme)
  }, [theme])

  return (
    <Ctx.Provider
      value={{
        theme,
        set: setTheme,
        toggle: () => setTheme((t) => (t === 'dark' ? 'light' : 'dark')),
      }}
    >
      {children}
    </Ctx.Provider>
  )
}

export function useTheme() {
  const c = useContext(Ctx)
  if (!c) throw new Error('useTheme outside provider')
  return c
}
