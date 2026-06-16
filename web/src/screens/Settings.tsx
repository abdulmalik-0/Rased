import { useEffect, useState } from 'react'
import { BarChart3, Database, Download, Loader2, Save, Sparkles } from 'lucide-react'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { useI18n } from '../lib/i18n'
import { useSettings } from '../lib/settings'
import { useToast } from '../lib/toast'
import { isAdmin } from '../lib/types'

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

      <AdminTools />
    </div>
  )
}

function AdminTools() {
  const { t } = useI18n()
  const { session } = useAuth()
  const toast = useToast()
  const [usage, setUsage] = useState<
    { user_id: string; model: string; tokens: number; calls: number }[]
  >([])
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    if (!isAdmin(session)) return
    api
      .getUsage()
      .then((u) => setUsage(u as unknown as typeof usage))
      .catch(() => {})
  }, [session])

  if (!isAdmin(session)) return null

  async function backup() {
    setBusy(true)
    try {
      await api.downloadBackup()
      toast('OK')
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Error')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="card space-y-4 p-5">
      <div className="flex items-center gap-2.5">
        <span className="grid h-9 w-9 place-items-center rounded-xl bg-primary/10 text-primary">
          <Database size={18} />
        </span>
        <div className="font-semibold text-text-primary">{t('adminTools')}</div>
      </div>

      <button
        onClick={backup}
        disabled={busy}
        className="flex items-center gap-2 rounded-xl border border-line bg-bg px-4 py-2.5 text-sm font-medium text-text-primary transition hover:bg-elevated disabled:opacity-50"
      >
        {busy ? <Loader2 className="animate-spin" size={16} /> : <Download size={16} />}
        {t('backupDb')}
      </button>

      {usage.length > 0 && (
        <div>
          <div className="mb-2 flex items-center gap-1.5 text-sm font-medium text-text-primary">
            <BarChart3 size={15} /> {t('aiUsage')}
          </div>
          <div className="overflow-hidden rounded-xl border border-line/60">
            <table className="w-full text-sm">
              <thead className="bg-elevated text-xs text-text-secondary">
                <tr>
                  <th className="p-2 text-start font-medium">user</th>
                  <th className="p-2 text-start font-medium">model</th>
                  <th className="p-2 text-end font-medium">{t('tokens')}</th>
                  <th className="p-2 text-end font-medium">{t('calls')}</th>
                </tr>
              </thead>
              <tbody>
                {usage.map((u, i) => (
                  <tr key={i} className="border-t border-line/60 text-text-primary">
                    <td className="max-w-[140px] truncate p-2">{u.user_id || '—'}</td>
                    <td className="max-w-[140px] truncate p-2">{u.model}</td>
                    <td className="p-2 text-end">{u.tokens}</td>
                    <td className="p-2 text-end">{u.calls}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
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
