import { useState } from 'react'
import { Loader2, ScrollText, Sparkles } from 'lucide-react'
import { api } from '../lib/api'
import { useI18n } from '../lib/i18n'
import { useSettings } from '../lib/settings'
import { useToast } from '../lib/toast'
import { Markdown } from './Markdown'

export function DigestCard({ hostId }: { hostId: string }) {
  const { t, lang } = useI18n()
  const { config } = useSettings()
  const toast = useToast()
  const [busy, setBusy] = useState(false)
  const [text, setText] = useState<string | null>(null)
  const [model, setModel] = useState('')

  async function generate() {
    if (!config?.base_url || !config?.model_name) {
      toast(t('digestNoAi'))
      return
    }
    setBusy(true)
    try {
      const r = await api.getDigest({ aiConfig: config, hostId, days: 7, lang })
      setText(r.digest)
      setModel(r.model_used)
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Error')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="card p-5">
      <div className="flex flex-wrap items-center gap-3">
        <span className="grid h-9 w-9 place-items-center rounded-xl bg-primary/10 text-primary">
          <ScrollText size={18} />
        </span>
        <div className="min-w-0 flex-1">
          <div className="text-sm font-semibold text-text-primary">{t('digestTitle')}</div>
          <div className="text-xs text-text-secondary">{t('digestHint')}</div>
        </div>
        <button
          onClick={generate}
          disabled={busy}
          className="flex items-center gap-2 rounded-xl border border-primary/60 px-3.5 py-2 text-sm font-medium text-primary transition hover:bg-primary/10 disabled:opacity-50"
        >
          {busy ? <Loader2 size={16} className="animate-spin" /> : <Sparkles size={16} />}
          {busy ? t('digestGenerating') : t('digestGenerate')}
        </button>
      </div>

      {text && (
        <div className="mt-4 animate-fade-in border-t border-line/60 pt-4">
          <Markdown text={text} />
          {model && (
            <div className="panel-label mt-3">
              {t('digestRange')} · {model}
            </div>
          )}
        </div>
      )}
    </div>
  )
}
