import { useCallback, useEffect, useRef, useState } from 'react'
import { Loader2, Terminal } from 'lucide-react'
import { Dialog } from '../Dialog'
import { api } from '../../lib/api'
import { useI18n } from '../../lib/i18n'
import type { ContainerMetrics } from '../../lib/types'

const POLL_MS = 2500

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
  const [live, setLive] = useState(true)
  const preRef = useRef<HTMLPreElement>(null)

  const load = useCallback(async () => {
    try {
      setLines(await api.fetchLogs(container.id, 200, apiUrl))
      setError(null)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Error')
    }
  }, [container.id, apiUrl])

  // Initial load whenever it opens / the container changes.
  useEffect(() => {
    if (!open) return
    setLines(null)
    setError(null)
    setLive(true)
    load()
  }, [open, load])

  // Live tail: re-poll on an interval while enabled.
  useEffect(() => {
    if (!open || !live) return
    const id = setInterval(load, POLL_MS)
    return () => clearInterval(id)
  }, [open, live, load])

  // Keep the newest lines in view while tailing.
  useEffect(() => {
    if (live && preRef.current) preRef.current.scrollTop = preRef.current.scrollHeight
  }, [lines, live])

  return (
    <Dialog
      open={open}
      onClose={onClose}
      maxWidth="max-w-3xl"
      icon={<Terminal className="text-primary" size={18} />}
      title={`${t('logsTitle')} — ${container.name}`}
    >
      <div className="mb-3 flex items-center justify-end">
        <button
          onClick={() => setLive((v) => !v)}
          className={`chip border transition ${
            live
              ? 'border-accent/40 bg-accent/12 text-accent'
              : 'border-line/70 text-text-secondary hover:text-text-primary'
          }`}
        >
          <span className="relative grid h-1.5 w-1.5 place-items-center">
            <span className={`h-1.5 w-1.5 rounded-full ${live ? 'bg-accent' : 'bg-text-secondary'}`} />
            {live && <span className="absolute h-1.5 w-1.5 rounded-full bg-accent animate-ping2" />}
          </span>
          {t('liveTail')}
        </button>
      </div>

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
          ref={preRef}
          dir="ltr"
          className="max-h-[60vh] overflow-auto whitespace-pre-wrap rounded-lg border border-line bg-elevated p-3 font-mono text-xs leading-relaxed text-text-primary"
        >
          {lines.join('\n')}
        </pre>
      )}
    </Dialog>
  )
}
