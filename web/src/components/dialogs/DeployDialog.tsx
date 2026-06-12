import { useState } from 'react'
import {
  AlertTriangle,
  CheckCircle2,
  Copy,
  ExternalLink,
  Loader2,
  Rocket,
  Sparkles,
} from 'lucide-react'
import { Dialog } from '../Dialog'
import { api } from '../../lib/api'
import { useI18n } from '../../lib/i18n'
import { useSettings } from '../../lib/settings'
import { useCopy } from '../../lib/useCopy'
import type { DeployPlan, DeployResult } from '../../lib/types'

function dockerRun(p: DeployPlan): string {
  const parts = ['docker run -d']
  if (p.name) parts.push(`--name ${p.name}`)
  if (p.restart) parts.push(`--restart ${p.restart}`)
  for (const port of p.ports) parts.push(`-p ${port.host}:${port.container}`)
  for (const v of p.volumes) parts.push(`-v ${v.host}:${v.container}`)
  for (const [k, val] of Object.entries(p.env)) parts.push(`-e ${k}=${val}`)
  parts.push(p.image)
  return parts.join(' ')
}

export function DeployDialog({
  open,
  onClose,
  apiUrl,
  deviceLabel,
}: {
  open: boolean
  onClose: () => void
  apiUrl: string
  deviceLabel: string
}) {
  const { t, lang } = useI18n()
  const { config } = useSettings()
  const copy = useCopy()
  const [mode, setMode] = useState<'image' | 'describe'>('image')
  const [image, setImage] = useState('')
  const [desc, setDesc] = useState('')
  const [plan, setPlan] = useState<DeployPlan | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [result, setResult] = useState<DeployResult | null>(null)

  const host = (() => {
    try {
      return new URL(apiUrl).hostname
    } catch {
      return ''
    }
  })()

  function switchMode(m: 'image' | 'describe') {
    setMode(m)
    setError(null)
    setResult(null)
    setPlan(null)
  }

  async function installImage() {
    if (!image.trim() || busy) return
    setBusy(true)
    setError(null)
    try {
      setResult(await api.runImage(image.trim(), '', apiUrl))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Error')
    } finally {
      setBusy(false)
    }
  }

  async function doPlan() {
    if (!desc.trim() || busy) return
    if (!config || !config.model_name) {
      setError(t('configureFirst'))
      return
    }
    setBusy(true)
    setError(null)
    setPlan(null)
    setResult(null)
    try {
      setPlan(await api.planDeploy({ description: desc.trim(), aiConfig: config, lang }))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Error')
    } finally {
      setBusy(false)
    }
  }

  async function installPlan() {
    if (!plan || busy) return
    setBusy(true)
    setError(null)
    try {
      setResult(await api.runDeploy(plan, apiUrl))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Error')
    } finally {
      setBusy(false)
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
      <div className="mb-4 flex rounded-xl border border-line/70 bg-surface p-0.5">
        {(['image', 'describe'] as const).map((m) => (
          <button
            key={m}
            onClick={() => switchMode(m)}
            className={`flex-1 rounded-lg py-1.5 text-sm font-medium transition ${
              mode === m
                ? 'bg-primary text-white'
                : 'text-text-secondary hover:text-text-primary'
            }`}
          >
            {m === 'image' ? t('deployByImage') : t('deployDescribe')}
          </button>
        ))}
      </div>

      {result ? (
        <Result result={result} host={host} okLabel={t('deployInstalled')} openLabel={t('openAt')} />
      ) : mode === 'image' ? (
        <>
          <div className="flex gap-2">
            <input
              value={image}
              onChange={(e) => setImage(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && installImage()}
              placeholder={t('deployImageHint')}
              dir="ltr"
              className="flex-1 rounded-xl border border-line bg-bg px-3.5 py-2.5 font-mono text-sm text-text-primary outline-none focus:border-primary"
            />
            <button
              onClick={installImage}
              disabled={busy}
              className="flex items-center gap-1.5 rounded-xl bg-primary px-3.5 py-2.5 text-sm font-medium text-white hover:opacity-90 disabled:opacity-50"
            >
              {busy ? <Loader2 className="animate-spin" size={16} /> : <Rocket size={16} />}
              {t('deployImageBtn')}
            </button>
          </div>
          <div className="mt-2 flex items-start gap-1.5 text-xs text-warning">
            <AlertTriangle size={14} className="mt-0.5 shrink-0" />
            {t('deployWarning')} ({t('deployOn')} {deviceLabel})
          </div>
          {error && <div className="mt-2 text-sm text-danger">{error}</div>}
        </>
      ) : !plan ? (
        <>
          <p className="mb-3 text-sm text-text-secondary">{t('deployIntro')}</p>
          <div className="flex gap-2">
            <input
              value={desc}
              onChange={(e) => setDesc(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && doPlan()}
              placeholder="n8n, uptime-kuma, postgres, …"
              className="flex-1 rounded-xl border border-line bg-bg px-3.5 py-2.5 text-sm text-text-primary outline-none focus:border-primary"
            />
            <button
              onClick={doPlan}
              disabled={busy}
              className="flex items-center gap-1.5 rounded-xl bg-primary px-3.5 py-2.5 text-sm font-medium text-white hover:opacity-90 disabled:opacity-50"
            >
              {busy ? <Loader2 className="animate-spin" size={16} /> : <Sparkles size={16} />}
              {t('deployPlanBtn')}
            </button>
          </div>
          {error && <div className="mt-3 text-sm text-danger">{error}</div>}
        </>
      ) : (
        <>
          <div className="card space-y-1.5 bg-bg/50 p-4">
            <Row label={t('planImage')} value={plan.image} />
            {plan.name && <Row label="name" value={plan.name} />}
            {plan.ports.length > 0 && (
              <Row
                label={t('planPorts')}
                value={plan.ports.map((p) => `${p.host}:${p.container}`).join(', ')}
              />
            )}
            {plan.volumes.length > 0 && (
              <Row
                label={t('planVolumes')}
                value={plan.volumes.map((v) => `${v.host} → ${v.container}`).join(', ')}
              />
            )}
            {Object.keys(plan.env).length > 0 && (
              <Row label={t('planEnv')} value={Object.keys(plan.env).join(', ')} />
            )}
            {plan.notes && <p className="pt-1 text-xs text-text-secondary">{plan.notes}</p>}
          </div>

          <div className="mt-3 rounded-xl border border-line bg-elevated p-3">
            <div className="mb-1 flex items-center justify-between">
              <span className="text-xs text-text-secondary">{t('equivalentCmd')}</span>
              <button
                onClick={() => copy(dockerRun(plan))}
                className="flex items-center gap-1 rounded px-1.5 py-0.5 text-xs text-primary hover:bg-surface"
              >
                <Copy size={13} /> {t('copy')}
              </button>
            </div>
            <pre dir="ltr" className="whitespace-pre-wrap break-all font-mono text-xs leading-relaxed text-text-primary">
              {dockerRun(plan)}
            </pre>
          </div>

          <div className="mt-3 flex items-start gap-1.5 text-xs text-warning">
            <AlertTriangle size={14} className="mt-0.5 shrink-0" />
            {t('deployWarning')}
          </div>
          {error && <div className="mt-2 text-sm text-danger">{error}</div>}
          <div className="mt-3 flex items-center gap-2">
            <button
              onClick={() => setPlan(null)}
              className="rounded-xl px-3 py-2 text-sm text-text-secondary hover:bg-elevated"
            >
              {t('deployReplan')}
            </button>
            <button
              onClick={installPlan}
              disabled={busy}
              className="ms-auto flex items-center gap-1.5 rounded-xl bg-primary px-4 py-2 text-sm font-semibold text-white hover:opacity-90 disabled:opacity-50"
            >
              {busy ? <Loader2 className="animate-spin" size={16} /> : <Rocket size={16} />}
              {t('deployInstall')} {t('deployOn')} {deviceLabel}
            </button>
          </div>
        </>
      )}
    </Dialog>
  )
}

function Result({
  result,
  host,
  okLabel,
  openLabel,
}: {
  result: DeployResult
  host: string
  okLabel: string
  openLabel: string
}) {
  return (
    <div className="rounded-xl border border-accent/40 bg-accent/10 p-4">
      <div className="flex items-center gap-2 text-sm font-medium text-accent">
        <CheckCircle2 size={18} /> {okLabel} — {result.name} · {result.status}
      </div>
      {result.ports.length > 0 && host && (
        <div className="mt-3 flex flex-wrap gap-2">
          {result.ports.map((p) => (
            <a
              key={p.host}
              href={`http://${host}:${p.host}`}
              target="_blank"
              rel="noreferrer"
              className="chip bg-surface text-primary hover:opacity-80"
            >
              <ExternalLink size={12} /> {openLabel} :{p.host}
            </a>
          ))}
        </div>
      )}
    </div>
  )
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex gap-2 text-sm">
      <span className="w-20 shrink-0 text-text-secondary">{label}</span>
      <span dir="ltr" className="min-w-0 flex-1 break-all font-mono text-text-primary">
        {value}
      </span>
    </div>
  )
}
