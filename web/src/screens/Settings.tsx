import { useEffect, useState } from 'react'
import { BarChart3, Bell, Database, Download, Loader2, Save, Sparkles } from 'lucide-react'
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
              className="flex w-full items-center justify-center gap-2 rounded-xl bg-primary py-2.5 font-semibold text-on-primary shadow-lg shadow-primary/20 transition hover:opacity-90 disabled:opacity-50"
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

      <AlertingConfig />
      <AdminTools />
    </div>
  )
}

function AlertingConfig() {
  const { t } = useI18n()
  const { session } = useAuth()
  const toast = useToast()
  const [cfg, setCfg] = useState<Record<string, string>>({})
  const [loaded, setLoaded] = useState(false)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (!isAdmin(session)) return
    api
      .getAdminConfig()
      .then((c) => {
        const s: Record<string, string> = {}
        for (const [k, v] of Object.entries(c)) s[k] = v == null ? '' : String(v)
        setCfg(s)
        setLoaded(true)
      })
      .catch(() => setLoaded(true))
  }, [session])

  if (!isAdmin(session)) return null
  const set = (k: string) => (v: string) => setCfg((p) => ({ ...p, [k]: v }))

  async function save() {
    setSaving(true)
    try {
      // empty string -> null so numeric overrides are cleared (not "" → NaN)
      const payload = Object.fromEntries(
        Object.entries(cfg).map(([k, v]) => [k, v.trim() === '' ? null : v]),
      )
      await api.setAdminConfig(payload)
      toast(t('settingsSaved'))
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Error')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="card space-y-4 p-5">
      <div className="flex items-center gap-2.5">
        <span className="grid h-9 w-9 place-items-center rounded-xl bg-primary/10 text-primary">
          <Bell size={18} />
        </span>
        <div>
          <div className="font-semibold text-text-primary">{t('notifTitle')}</div>
          <div className="text-xs text-text-secondary">{t('notifHint')}</div>
        </div>
      </div>

      {!loaded ? (
        <div className="grid place-items-center py-6">
          <Loader2 className="animate-spin text-primary" size={20} />
        </div>
      ) : (
        <>
          <Input
            label={t('webhookUrl')}
            value={cfg.alert_webhook_url ?? ''}
            onChange={set('alert_webhook_url')}
            placeholder="https://hooks.slack.com/services/…"
          />
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <Input
              label={t('telegramToken')}
              value={cfg.telegram_bot_token ?? ''}
              onChange={set('telegram_bot_token')}
              type="password"
            />
            <Input
              label={t('telegramChat')}
              value={cfg.telegram_chat_id ?? ''}
              onChange={set('telegram_chat_id')}
            />
          </div>

          <div className="text-xs font-medium text-text-secondary">
            {t('globalThresholds')}
          </div>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            <Input label={t('hostCpu')} value={cfg.cpu_alert_percent ?? ''} onChange={set('cpu_alert_percent')} type="number" />
            <Input label={t('hostMemory')} value={cfg.mem_alert_percent ?? ''} onChange={set('mem_alert_percent')} type="number" />
            <Input label={t('disk')} value={cfg.disk_alert_percent ?? ''} onChange={set('disk_alert_percent')} type="number" />
            <Input label={t('battery')} value={cfg.battery_alert_percent ?? ''} onChange={set('battery_alert_percent')} type="number" />
          </div>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <Input label={t('cooldownSecs')} value={cfg.alert_cooldown_seconds ?? ''} onChange={set('alert_cooldown_seconds')} type="number" />
            <Input label={t('aiBudget')} value={cfg.ai_monthly_token_budget ?? ''} onChange={set('ai_monthly_token_budget')} type="number" />
          </div>

          <label className="flex cursor-pointer items-start gap-2.5 rounded-xl border border-line/60 bg-bg/50 p-3">
            <input
              type="checkbox"
              checked={(cfg.anomaly_detection_enabled ?? 'true') !== 'false'}
              onChange={(e) =>
                set('anomaly_detection_enabled')(e.target.checked ? 'true' : 'false')
              }
              className="mt-0.5 h-4 w-4 accent-primary"
            />
            <span>
              <span className="block text-sm font-medium text-text-primary">
                {t('anomalyDetection')}
              </span>
              <span className="block text-xs text-text-secondary">
                {t('anomalyHint')}
              </span>
            </span>
          </label>

          <button
            onClick={save}
            disabled={saving}
            className="flex items-center gap-2 rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-on-primary transition hover:opacity-90 disabled:opacity-50"
          >
            {saving ? <Loader2 className="animate-spin" size={16} /> : <Save size={16} />}
            {t('saveSettings')}
          </button>
        </>
      )}
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
