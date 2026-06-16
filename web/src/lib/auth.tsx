import {
  createContext,
  useCallback,
  useContext,
  useState,
  type ReactNode,
} from 'react'
import { api, decodeJwt, setAuthToken } from './api'
import type { AuthSession } from './types'

const KEY = 'auth_token'

function load(): AuthSession | null {
  const t = localStorage.getItem(KEY)
  if (!t) return null
  const claims = decodeJwt(t)
  const exp = claims.exp as number | undefined
  if (exp && exp * 1000 < Date.now()) {
    localStorage.removeItem(KEY)
    return null
  }
  setAuthToken(t)
  return {
    token: t,
    email: String(claims.email ?? ''),
    role: String(claims.role ?? 'viewer'),
  }
}

interface AuthCtx {
  session: AuthSession | null
  login: (email: string, password: string) => Promise<void>
  /** returns true when the account is created but pending approval */
  register: (email: string, password: string) => Promise<boolean>
  logout: () => void
}
const Ctx = createContext<AuthCtx | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<AuthSession | null>(load)

  const login = useCallback(async (email: string, password: string) => {
    const s = await api.login(email, password)
    localStorage.setItem(KEY, s.token)
    setAuthToken(s.token)
    setSession(s)
  }, [])

  const register = useCallback(async (email: string, password: string) => {
    const r = await api.register(email, password)
    if (r.pending || !r.session) return true
    localStorage.setItem(KEY, r.session.token)
    setAuthToken(r.session.token)
    setSession(r.session)
    return false
  }, [])

  const logout = useCallback(() => {
    api.logout() // revoke server-side (bumps token_version); fire-and-forget
    localStorage.removeItem(KEY)
    setAuthToken(null)
    setSession(null)
  }, [])

  return (
    <Ctx.Provider value={{ session, login, register, logout }}>
      {children}
    </Ctx.Provider>
  )
}

export function useAuth() {
  const c = useContext(Ctx)
  if (!c) throw new Error('useAuth outside provider')
  return c
}
