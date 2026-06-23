import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Copy, Loader2, MessageSquare, Play, Sparkles } from 'lucide-react'
import { Dialog } from '../Dialog'
import { Markdown } from '../Markdown'
import { api } from '../../lib/api'
import { useI18n } from '../../lib/i18n'
import { useSettings } from '../../lib/settings'
import { useCopy } from '../../lib/useCopy'
import type { ContainerMetrics } from '../../lib/types'

export function AnalyzeDialog({
  open,
  onClose,
  container,
  apiUrl,
  hostId,
}: {
  open: boolean
  onClose: () => void
  container: ContainerMetrics
  apiUrl: string
  hostId: string
}) {
  const { t, lang } = useI18n()
  const { config } = useSettings()
  const copy = useCopy()
  const navigate = useNavigate()
  const [result, setResult] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [chatId, setChatId] = useState<string | null>(null)

  async function run() {
    if (!config || !config.model_name) {
      setError(t('configureFirst'))
      return
    }
    setLoading(true)
    setError(null)
    setResult(null)
    try {
      const r = await api.analyzeLogs({
        containerId: container.id,
        aiConfig: config,
        baseUrl: apiUrl,
        lang,
      })
      setResult(r.analysis)
      try {
        const id = await api.upsertChat({
          host_id: hostId,
          title: `🔍 ${container.name}`,
          messages: [
            { role: 'user', content: `Analyze logs: ${container.name}` },
            { role: 'assistant', content: r.analysis },
          ],
        })
        setChatId(id)
      } catch {
        /* ignore */
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Error')
    } finally {
      setLoading(false)
    }
  }

  function continueChat() {
    onClose()
    navigate('/chat', {
      state: {
        hostId,
        apiUrl,
        initialChatId: chatId,
        initialMessages: result
          ? [
              { role: 'user', content: `Analyze logs: ${container.name}` },
              { role: 'assistant', content: result },
            ]
          : undefined,
      },
    })
  }

  return (
    <Dialog
      open={open}
      onClose={onClose}
      maxWidth="max-w-2xl"
      icon={<Sparkles className="text-primary" size={18} />}
      title={`${t('aiLogAnalysis')} — ${container.name}`}
    >
      {!result && !loading && !error && (
        <div className="py-6 text-center">
          <Sparkles className="mx-auto mb-3 text-primary" size={36} />
          <p className="mb-5 text-sm text-text-secondary">{t('analyzeIntro')}</p>
          <button
            onClick={run}
            className="mx-auto flex items-center gap-2 rounded-xl bg-primary px-4 py-2.5 font-medium text-on-primary hover:opacity-90"
          >
            <Play size={16} /> {t('startAnalysis')}
          </button>
        </div>
      )}

      {loading && (
        <div className="grid place-items-center gap-2 py-12 text-text-secondary">
          <Loader2 className="animate-spin text-primary" size={28} />
          {t('analyzing')}
          <span className="text-xs">{t('redactNote')}</span>
        </div>
      )}

      {error && (
        <div className="py-8 text-center">
          <p className="mb-4 text-sm text-danger">{error}</p>
          <button
            onClick={run}
            className="rounded-lg border border-line px-4 py-2 text-sm text-text-primary hover:bg-elevated"
          >
            {t('retry')}
          </button>
        </div>
      )}

      {result && (
        <>
          <Markdown text={result} />
          <div className="mt-4 flex items-center gap-2 border-t border-line/60 pt-3">
            <button
              onClick={() => copy(result)}
              className="flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-sm text-text-secondary hover:bg-elevated"
            >
              <Copy size={15} /> {t('copyAll')}
            </button>
            <button
              onClick={continueChat}
              className="ms-auto flex items-center gap-1.5 rounded-lg bg-primary px-3 py-1.5 text-sm font-medium text-on-primary hover:opacity-90"
            >
              <MessageSquare size={15} /> {t('continueInChat')}
            </button>
          </div>
        </>
      )}
    </Dialog>
  )
}
