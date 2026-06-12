import { useState } from 'react'
import { Activity, Languages } from 'lucide-react'
import { useAuth } from '../lib/auth'
import { useI18n } from '../lib/i18n'

export default function Login() {
  const { login, register } = useAuth()
  const { t, toggle } = useI18n()
  const [mode, setMode] = useState<'login' | 'register'>('login')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [pending, setPending] = useState(false)

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    setBusy(true)
    setError(null)
    setPending(false)
    try {
      if (mode === 'login') await login(email.trim(), password)
      else {
        const isPending = await register(email.trim(), password)
        if (isPending) {
          setPending(true)
          setMode('login')
        }
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : t('authFailed'))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="grid min-h-full place-items-center p-4">
      <div className="w-full max-w-sm">
        <div className="mb-8 flex flex-col items-center text-center">
          <div className="mb-3 grid h-14 w-14 place-items-center rounded-2xl bg-gradient-to-br from-primary to-accent shadow-xl shadow-primary/25">
            <Activity className="text-white" size={28} />
          </div>
          <h1 className="text-2xl font-bold tracking-tight text-text-primary">
            {t('appTitle')}
          </h1>
          <p className="text-sm text-text-secondary">Server monitoring</p>
        </div>

        <div className="card animate-fade-in p-7">
          <div className="mb-5 flex items-center justify-between">
            <span className="text-base font-semibold text-text-primary">
              {mode === 'login' ? t('signIn') : t('register')}
            </span>
            <button onClick={toggle} className="btn-ghost" title={t('language')}>
              <Languages size={18} />
            </button>
          </div>

          {pending && (
            <div className="mb-4 rounded-xl border border-accent/40 bg-accent/10 px-3 py-2.5 text-sm text-accent">
              {t('pendingApproval')}
            </div>
          )}
          {error && (
            <div className="mb-4 rounded-xl border border-danger/40 bg-danger/10 px-3 py-2.5 text-sm text-danger">
              {error}
            </div>
          )}

          <form onSubmit={submit} className="space-y-4">
            <Field
              label={t('email')}
              type="email"
              value={email}
              onChange={setEmail}
              autoFocus
            />
            <Field
              label={t('password')}
              type="password"
              value={password}
              onChange={setPassword}
            />
            <button
              type="submit"
              disabled={busy}
              className="w-full rounded-xl bg-primary py-2.5 font-semibold text-white shadow-lg shadow-primary/20 transition hover:opacity-90 active:scale-[0.99] disabled:opacity-50"
            >
              {busy ? '…' : mode === 'login' ? t('signIn') : t('register')}
            </button>
          </form>

          <button
            onClick={() => {
              setMode((m) => (m === 'login' ? 'register' : 'login'))
              setError(null)
            }}
            className="mt-5 w-full text-center text-sm text-text-secondary transition hover:text-primary"
          >
            {mode === 'login' ? t('haveNoAccount') : t('haveAccount')}
          </button>
        </div>
      </div>
    </div>
  )
}

function Field(props: {
  label: string
  type: string
  value: string
  onChange: (v: string) => void
  autoFocus?: boolean
}) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-xs font-medium text-text-secondary">
        {props.label}
      </span>
      <input
        type={props.type}
        value={props.value}
        autoFocus={props.autoFocus}
        onChange={(e) => props.onChange(e.target.value)}
        required
        className="w-full rounded-xl border border-line bg-bg/60 px-3.5 py-2.5 text-text-primary outline-none ring-primary/30 transition focus:border-primary focus:ring-2"
      />
    </label>
  )
}
