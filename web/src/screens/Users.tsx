import { useEffect, useState } from 'react'
import { Check, Loader2, RefreshCw } from 'lucide-react'
import { Navigate } from 'react-router-dom'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { useI18n } from '../lib/i18n'
import { useToast } from '../lib/toast'
import { isAdmin } from '../lib/types'

interface Row {
  id: string
  email: string
  role: string
  approved: number | boolean
}

export default function Users() {
  const { t } = useI18n()
  const { session } = useAuth()
  const toast = useToast()
  const [users, setUsers] = useState<Row[]>([])
  const [loading, setLoading] = useState(true)
  const [err, setErr] = useState<string | null>(null)

  async function load() {
    setLoading(true)
    setErr(null)
    try {
      setUsers((await api.getUsers()) as unknown as Row[])
    } catch (e) {
      setErr(e instanceof Error ? e.message : t('usersError'))
    } finally {
      setLoading(false)
    }
  }
  useEffect(() => {
    load()
  }, [])

  async function approve(id: string) {
    try {
      await api.patchUser(id, { approved: true })
      toast(t('approved'))
      load()
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Error')
    }
  }
  async function setRole(id: string, role: string) {
    try {
      await api.patchUser(id, { role })
      load()
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Error')
    }
  }

  if (!isAdmin(session)) return <Navigate to="/" replace />

  return (
    <div className="mx-auto max-w-3xl space-y-5 p-4 sm:p-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold tracking-tight text-text-primary">
          {t('users')}
        </h1>
        <button
          onClick={load}
          className="btn-ghost border border-line/70 bg-surface"
          title={t('refresh')}
        >
          <RefreshCw size={16} />
        </button>
      </div>

      {loading ? (
        <div className="card grid place-items-center py-16 text-text-secondary">
          <Loader2 className="animate-spin text-primary" size={26} />
        </div>
      ) : err ? (
        <div className="card border-danger/30 p-4 text-sm text-danger">{err}</div>
      ) : users.length === 0 ? (
        <div className="card py-12 text-center text-text-secondary">
          {t('noUsers')}
        </div>
      ) : (
        <div className="card divide-y divide-line/60 overflow-hidden">
          {users.map((u) => {
            const approved = !!u.approved
            const isMe = u.email === session?.email
            return (
              <div key={u.id} className="flex flex-wrap items-center gap-3 p-4">
                <div className="grid h-9 w-9 place-items-center rounded-xl bg-primary/10 text-sm font-bold text-primary">
                  {u.email[0]?.toUpperCase()}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="truncate text-sm font-medium text-text-primary">
                    {u.email}
                    {isMe && (
                      <span className="ms-2 text-xs font-normal text-text-secondary">
                        ({t('you')})
                      </span>
                    )}
                  </div>
                  <div className="mt-0.5">
                    {approved ? (
                      <span className="chip bg-accent/12 text-accent">
                        <Check size={11} /> {t('approved')}
                      </span>
                    ) : (
                      <span className="chip bg-warning/12 text-warning">
                        {t('pending')}
                      </span>
                    )}
                  </div>
                </div>

                {!approved && (
                  <button
                    onClick={() => approve(u.id)}
                    className="rounded-lg bg-accent px-3 py-1.5 text-sm font-medium text-white transition hover:opacity-90"
                  >
                    {t('approve')}
                  </button>
                )}

                <select
                  value={u.role}
                  disabled={isMe}
                  onChange={(e) => setRole(u.id, e.target.value)}
                  className="rounded-lg border border-line bg-bg px-2.5 py-1.5 text-sm text-text-primary outline-none focus:border-primary disabled:opacity-50"
                >
                  <option value="admin">{t('roleAdmin')}</option>
                  <option value="viewer">{t('roleViewer')}</option>
                </select>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
