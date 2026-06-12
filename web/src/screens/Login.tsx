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
    <div className="min-h-full flex items-center justify-center p-4">
      <div className="w-full max-w-sm rounded-2xl border border-line bg-surface p-7 shadow-xl">
        <div className="mb-6 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Activity className="text-primary" size={26} />
            <span className="text-xl font-bold text-text-primary">{t('appTitle')}</span>
          </div>
          <button
            onClick={toggle}
            className="rounded-lg p-2 text-text-secondary hover:bg-elevated"
            title={t('language')}
          >
            <Languages size={18} />
          </button>
        </div>

        {pending && (
          <div className="mb-4 rounded-lg border border-accent/40 bg-accent/10 px-3 py-2 text-sm text-accent">
            {t('pendingApproval')}
          </div>
        )}
        {error && (
          <div className="mb-4 rounded-lg border border-danger/40 bg-danger/10 px-3 py-2 text-sm text-danger">
            {error}
          </div>
        )}

        <form onSubmit={submit} className="space-y-3">
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
            className="w-full rounded-lg bg-primary py-2.5 font-medium text-white transition hover:opacity-90 disabled:opacity-50"
          >
            {busy ? '…' : mode === 'login' ? t('signIn') : t('register')}
          </button>
        </form>

        <button
          onClick={() => {
            setMode((m) => (m === 'login' ? 'register' : 'login'))
            setError(null)
          }}
          className="mt-4 w-full text-center text-sm text-text-secondary hover:text-primary"
        >
          {mode === 'login' ? t('haveNoAccount') : t('haveAccount')}
        </button>
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
      <span className="mb-1 block text-xs text-text-secondary">{props.label}</span>
      <input
        type={props.type}
        value={props.value}
        autoFocus={props.autoFocus}
        onChange={(e) => props.onChange(e.target.value)}
        required
        className="w-full rounded-lg border border-line bg-bg px-3 py-2 text-text-primary outline-none focus:border-primary"
      />
    </label>
  )
}
