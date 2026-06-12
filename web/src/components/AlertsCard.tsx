import { AlertTriangle } from 'lucide-react'
import { useI18n } from '../lib/i18n'
import type { Alert } from '../lib/types'

export function AlertsCard({ alerts }: { alerts: Alert[] }) {
  const { t } = useI18n()
  if (!alerts.length) return null
  return (
    <div className="rounded-xl border border-warning/40 bg-warning/5 p-4">
      <div className="mb-2 flex items-center gap-2 font-semibold text-text-primary">
        <AlertTriangle size={18} className="text-warning" />
        {t('alerts')} ({alerts.length})
      </div>
      <ul className="space-y-1">
        {alerts.map((a, i) => (
          <li key={i} className="text-sm text-text-secondary">
            • {a.message}
          </li>
        ))}
      </ul>
    </div>
  )
}
