import { useEffect, useState } from 'react'
import { Loader2, Terminal } from 'lucide-react'
import { Dialog } from '../Dialog'
import { api } from '../../lib/api'
import { useI18n } from '../../lib/i18n'
import type { ContainerMetrics } from '../../lib/types'

export function LogsDialog({
  open,
  onClose,
  container,
  apiUrl,
}: {
  open: boolean
  onClose: () => void
  container: ContainerMetrics
  apiUrl: string
}) {
  const { t } = useI18n()
  const [lines, setLines] = useState<string[] | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setLines(null)
    setError(null)
    api
      .fetchLogs(container.id, 200, apiUrl)
      .then(setLines)
      .catch((e) => setError(e instanceof Error ? e.message : 'Error'))
  }, [open, container.id, apiUrl])

  return (
    <Dialog
      open={open}
      onClose={onClose}
      maxWidth="max-w-3xl"
      icon={<Terminal className="text-primary" size={18} />}
      title={`${t('logsTitle')} — ${container.name}`}
    >
      {error ? (
        <div className="text-sm text-danger">{error}</div>
      ) : !lines ? (
        <div className="grid place-items-center py-10">
          <Loader2 className="animate-spin text-primary" size={24} />
        </div>
      ) : lines.length === 0 ? (
        <div className="py-8 text-center text-text-secondary">{t('noLogs')}</div>
      ) : (
        <pre
          dir="ltr"
          className="max-h-[60vh] overflow-auto whitespace-pre-wrap rounded-lg border border-line bg-elevated p-3 font-mono text-xs leading-relaxed text-text-primary"
        >
          {lines.join('\n')}
        </pre>
      )}
    </Dialog>
  )
}
