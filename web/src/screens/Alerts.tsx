import { useEffect, useState } from 'react'
import { Check, CheckCheck, Loader2, RefreshCw } from 'lucide-react'
import { api } from '../lib/api'
import { useI18n } from '../lib/i18n'
import { useToast } from '../lib/toast'

interface Row {
  id: number
  ts: string
  host_id: string
  level: string
  message: string
  acknowledged: number
  resolved_at: string | null
}

const tone = (l: string) =>
  l === 'critical'
    ? 'bg-danger/12 text-danger'
    : l === 'warning'
      ? 'bg-warning/12 text-warning'
      : 'bg-elevated text-text-secondary'

export default function Alerts() {
  const { t } = useI18n()
  const toast = useToast()
  const [rows, setRows] = useState<Row[]>([])
  const [loading, setLoading] = useState(true)

  async function load() {
    setLoading(true)
    try {
      setRows((await api.getAlerts(undefined, 200)) as unknown as Row[])
    } catch {
      /* ignore */
    } finally {
      setLoading(false)
    }
  }
  useEffect(() => {
    load()
  }, [])

  async function act(id: number, action: 'ack' | 'resolve') {
    try {
      await api.patchAlert(id, action)
      load()
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Error')
    }
  }

  return (
    <div className="mx-auto max-w-3xl space-y-5 p-4 sm:p-6">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold tracking-tight text-text-primary">
          {t('alertsScreen')}
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
        <div className="card grid place-items-center py-16">
          <Loader2 className="animate-spin text-primary" size={26} />
        </div>
      ) : rows.length === 0 ? (
        <div className="card py-12 text-center text-text-secondary">
          {t('noAlerts')}
        </div>
      ) : (
        <div className="card divide-y divide-line/60 overflow-hidden">
          {rows.map((a) => (
            <div
              key={a.id}
              className={`flex items-start gap-3 p-4 ${a.resolved_at ? 'opacity-50' : ''}`}
            >
              <span className={`chip ${tone(a.level)} uppercase`}>{a.level}</span>
              <div className="min-w-0 flex-1">
                <div className="text-sm text-text-primary">{a.message}</div>
                <div className="mt-0.5 text-xs text-text-secondary">
                  {a.host_id} · {a.ts.slice(0, 16).replace('T', ' ')}
                  {a.acknowledged && !a.resolved_at ? ` · ${t('acked')}` : ''}
                </div>
              </div>
              {a.resolved_at ? (
                <span className="chip bg-accent/12 text-accent">
                  <CheckCheck size={12} /> {t('resolved')}
                </span>
              ) : (
                <div className="flex shrink-0 gap-1">
                  {!a.acknowledged && (
                    <button
                      onClick={() => act(a.id, 'ack')}
                      title={t('acknowledge')}
                      className="btn-ghost"
                    >
                      <Check size={16} />
                    </button>
                  )}
                  <button
                    onClick={() => act(a.id, 'resolve')}
                    title={t('resolve')}
                    className="btn-ghost text-accent"
                  >
                    <CheckCheck size={16} />
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
