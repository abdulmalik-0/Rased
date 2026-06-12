import { useEffect, useState } from 'react'
import { Loader2, Save, Sparkles } from 'lucide-react'
import { useI18n } from '../lib/i18n'
import { useSettings } from '../lib/settings'
import { useToast } from '../lib/toast'

const DEFAULTS: Record<string, string> = {
  ollama: 'http://localhost:11434/v1',
  lm_studio: 'http://localhost:1234/v1',
  anthropic: 'https://api.anthropic.com',
  cloud: '',
  custom: '',
}

export default function Settings() {
  const { t } = useI18n()
  const { config, loading, save } = useSettings()
  const toast = useToast()
  const [provider, setProvider] = useState('ollama')
  const [baseUrl, setBaseUrl] = useState('')
  const [model, setModel] = useState('')
  const [apiKey, setApiKey] = useState('')
  const [saving, setSaving] = useState(false)
  const [loaded, setLoaded] = useState(false)

  useEffect(() => {
    if (config && !loaded) {
      setProvider(config.provider_type || 'ollama')
      setBaseUrl(config.base_url || '')
      setModel(config.model_name || '')
      setApiKey(config.api_key || '')
      setLoaded(true)
    }
  }, [config, loaded])

  function onProvider(v: string) {
    setProvider(v)
    setBaseUrl(DEFAULTS[v] ?? '')
  }

  async function onSave() {
    if (!baseUrl.trim() || !model.trim()) {
      toast(t('required'))
      return
    }
    setSaving(true)
    try {
      await save({
        provider_type: provider,
        base_url: baseUrl.trim(),
        model_name: model.trim(),
        api_key: apiKey,
      })
      toast(t('settingsSaved'))
    } catch (e) {
      toast(e instanceof Error ? e.message : t('settingsSaveFailed'))
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="mx-auto max-w-2xl space-y-5 p-4 sm:p-6">
      <h1 className="text-xl font-bold tracking-tight text-text-primary">
        {t('settings')}
      </h1>

      <div className="card space-y-4 p-5">
        <div className="flex items-center gap-2.5">
          <span className="grid h-9 w-9 place-items-center rounded-xl bg-primary/10 text-primary">
            <Sparkles size={18} />
          </span>
          <div>
            <div className="font-semibold text-text-primary">{t('aiProvider')}</div>
            <div className="text-xs text-text-secondary">{t('configureProvider')}</div>
          </div>
        </div>

        {loading ? (
          <div className="grid place-items-center py-8">
            <Loader2 className="animate-spin text-primary" size={24} />
          </div>
        ) : (
          <>
            <label className="block">
              <span className="mb-1.5 block text-xs font-medium text-text-secondary">
                {t('providerType')}
              </span>
              <select
                value={provider}
                onChange={(e) => onProvider(e.target.value)}
                className="w-full rounded-xl border border-line bg-bg px-3 py-2.5 text-text-primary outline-none focus:border-primary"
              >
                <option value="ollama">{t('providerOllama')}</option>
                <option value="lm_studio">{t('providerLmStudio')}</option>
                <option value="anthropic">{t('providerAnthropic')}</option>
                <option value="cloud">{t('providerCloud')}</option>
                <option value="custom">{t('providerCustom')}</option>
              </select>
            </label>

            <Input label={t('baseUrl')} value={baseUrl} onChange={setBaseUrl} placeholder="https://api.openai.com/v1" />
            <Input label={t('modelName')} value={model} onChange={setModel} placeholder="llama3.2, gpt-4o, claude-…" />
            <Input
              label={t('apiKey')}
              value={apiKey}
              onChange={setApiKey}
              type="password"
              placeholder={
                provider === 'ollama' || provider === 'lm_studio'
                  ? t('apiKeyOptional')
                  : t('apiKeyRequired')
              }
            />
            <p className="text-xs text-text-secondary">{t('apiKeyEncrypted')}</p>

            <button
              onClick={onSave}
              disabled={saving}
              className="flex w-full items-center justify-center gap-2 rounded-xl bg-primary py-2.5 font-semibold text-white shadow-lg shadow-primary/20 transition hover:opacity-90 disabled:opacity-50"
            >
              {saving ? (
                <Loader2 className="animate-spin" size={18} />
              ) : (
                <Save size={18} />
              )}
              {t('saveSettings')}
            </button>
          </>
        )}
      </div>
    </div>
  )
}

function Input(props: {
  label: string
  value: string
  onChange: (v: string) => void
  type?: string
  placeholder?: string
}) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-xs font-medium text-text-secondary">
        {props.label}
      </span>
      <input
        type={props.type ?? 'text'}
        value={props.value}
        placeholder={props.placeholder}
        onChange={(e) => props.onChange(e.target.value)}
        className="w-full rounded-xl border border-line bg-bg px-3.5 py-2.5 text-text-primary outline-none ring-primary/30 transition focus:border-primary focus:ring-2"
      />
    </label>
  )
}
