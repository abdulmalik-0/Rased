import { useState } from 'react'
import { Copy, Loader2, Rocket, Sparkles } from 'lucide-react'
import { Dialog } from '../Dialog'
import { Markdown } from '../Markdown'
import { api } from '../../lib/api'
import { useI18n } from '../../lib/i18n'
import { useSettings } from '../../lib/settings'
import { useCopy } from '../../lib/useCopy'

export function DeployDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { t, lang } = useI18n()
  const { config } = useSettings()
  const copy = useCopy()
  const [desc, setDesc] = useState('')
  const [result, setResult] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)

  async function run() {
    if (!desc.trim() || loading) return
    if (!config || !config.model_name) {
      setError(t('configureFirst'))
      return
    }
    setLoading(true)
    setError(null)
    setResult(null)
    try {
      setResult(
        await api.suggestDeploy({ description: desc.trim(), aiConfig: config, lang }),
      )
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Error')
    } finally {
      setLoading(false)
    }
  }

  return (
    <Dialog
      open={open}
      onClose={onClose}
      maxWidth="max-w-2xl"
      icon={<Rocket className="text-primary" size={18} />}
      title={t('deployTitle')}
    >
      <p className="mb-3 text-sm text-text-secondary">{t('deployIntro')}</p>
      <div className="flex gap-2">
        <input
          value={desc}
          onChange={(e) => setDesc(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && run()}
          placeholder="n8n + postgres, uptime-kuma, …"
          className="flex-1 rounded-xl border border-line bg-bg px-3.5 py-2.5 text-sm text-text-primary outline-none focus:border-primary"
        />
        <button
          onClick={run}
          disabled={loading}
          className="flex items-center gap-1.5 rounded-xl bg-primary px-3.5 py-2.5 text-sm font-medium text-white hover:opacity-90 disabled:opacity-50"
        >
          {loading ? (
            <Loader2 className="animate-spin" size={16} />
          ) : (
            <Sparkles size={16} />
          )}
          {t('deploySuggest')}
        </button>
      </div>

      <div className="mt-4">
        {error ? (
          <div className="text-sm text-danger">{error}</div>
        ) : loading ? (
          <div className="grid place-items-center py-10">
            <Loader2 className="animate-spin text-primary" size={26} />
          </div>
        ) : !result ? (
          <div className="py-10 text-center text-sm text-text-secondary">
            {t('deployEmpty')}
          </div>
        ) : (
          <>
            <Markdown text={result} />
            <div className="mt-3 flex items-center gap-2 border-t border-line/60 pt-3">
              <span className="flex-1 text-xs text-warning">{t('deployReviewNote')}</span>
              <button
                onClick={() => copy(result)}
                className="flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-sm text-text-secondary hover:bg-elevated"
              >
                <Copy size={15} /> {t('copyAll')}
              </button>
            </div>
          </>
        )}
      </div>
    </Dialog>
  )
}
