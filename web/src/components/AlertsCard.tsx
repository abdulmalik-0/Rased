import { AlertTriangle } from 'lucide-react'
import { useI18n } from '../lib/i18n'
import type { Alert } from '../lib/types'

export function AlertsCard({ alerts }: { alerts: Alert[] }) {
  const { t } = useI18n()
  if (!alerts.length) return null
  return (
    <div className="card border-warning/30 bg-warning/[0.04] p-4">
      <div className="mb-3 flex items-center gap-2.5">
        <span className="grid h-8 w-8 place-items-center rounded-xl bg-warning/10 text-warning">
          <AlertTriangle size={16} />
        </span>
        <span className="font-semibold text-text-primary">{t('alerts')}</span>
        <span className="chip bg-warning/15 text-warning">{alerts.length}</span>
      </div>
      <ul className="space-y-1.5">
        {alerts.map((a, i) => (
          <li key={i} className="flex items-start gap-2 text-sm text-text-secondary">
            <span className="mt-1.5 h-1 w-1 shrink-0 rounded-full bg-warning" />
            {a.message}
          </li>
        ))}
      </ul>
    </div>
  )
}
