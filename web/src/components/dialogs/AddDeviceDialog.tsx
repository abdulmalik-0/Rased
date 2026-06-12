import { useEffect, useState } from 'react'
import { Copy, Eye, EyeOff, Loader2, PlusSquare } from 'lucide-react'
import { Dialog } from '../Dialog'
import { Field } from '../Field'
import { api } from '../../lib/api'
import { useI18n } from '../../lib/i18n'
import { useCopy } from '../../lib/useCopy'

const DEFAULT_REPO = 'https://github.com/abdulmalik-0/Rased.git'

function rawBootstrap(repo: string) {
  let r = repo.trim()
  if (r.endsWith('.git')) r = r.slice(0, -4)
  if (r.endsWith('/')) r = r.slice(0, -1)
  r = r.replace('github.com', 'raw.githubusercontent.com')
  return `${r}/main/scripts/bootstrap-agent.sh`
}
const mask = (s: string) => (s.length <= 6 ? '••••••' : s.slice(0, 4) + '•'.repeat(16))

export function AddDeviceDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { t } = useI18n()
  const copy = useCopy()
  const [setup, setSetup] = useState<Record<string, unknown> | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [hostId, setHostId] = useState('lxc-2')
  const [name, setName] = useState('LXC 2')
  const [repo, setRepo] = useState(
    () => localStorage.getItem('agent_repo_url') || DEFAULT_REPO,
  )
  const [reveal, setReveal] = useState(false)

  useEffect(() => {
    if (!open) return
    setError(null)
    setSetup(null)
    api
      .getAgentSetup()
      .then(setSetup)
      .catch((e) => setError(e instanceof Error ? e.message : 'Error'))
  }, [open])

  const central = String(setup?.central_ingest_url ?? '')
  const token = String(setup?.agent_token ?? '')
  const jwt = String(setup?.jwt_secret ?? '')
  const raw = rawBootstrap(repo)
  const cmd = (tk: string, jw: string) =>
    `curl -fsSL ${raw} | bash -s -- --central ${central} --token ${tk} --jwt ${jw} --id ${hostId || 'lxc-2'} --name "${name || 'LXC'}"`
  const realCmd = cmd(token, jwt)
  const shownCmd = reveal ? realCmd : cmd(mask(token), mask(jwt))

  return (
    <Dialog
      open={open}
      onClose={onClose}
      maxWidth="max-w-2xl"
      icon={<PlusSquare className="text-primary" size={18} />}
      title={t('addDeviceTitle')}
    >
      <p className="mb-4 text-sm text-text-secondary">{t('addDeviceIntro')}</p>
      {error ? (
        <div className="text-sm text-danger">{error}</div>
      ) : !setup ? (
        <div className="grid place-items-center py-10">
          <Loader2 className="animate-spin text-primary" size={24} />
        </div>
      ) : (
        <>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <Field label={t('agentHostId')} value={hostId} onChange={setHostId} dir="ltr" />
            <Field label={t('displayName')} value={name} onChange={setName} />
          </div>
          <div className="mt-3">
            <Field
              label={t('agentRepoUrl')}
              value={repo}
              onChange={(v) => {
                setRepo(v)
                localStorage.setItem('agent_repo_url', v)
              }}
              dir="ltr"
            />
          </div>

          <div className="mt-4 text-sm font-semibold text-text-primary">
            {t('addDeviceRun')}
          </div>
          <div className="mt-1.5 rounded-xl border border-line bg-elevated p-3">
            <pre
              dir="ltr"
              className="whitespace-pre-wrap break-all font-mono text-xs leading-relaxed text-text-primary"
            >
              {shownCmd}
            </pre>
            <div className="mt-2 flex items-center justify-end gap-1">
              <button
                onClick={() => setReveal((r) => !r)}
                className="flex items-center gap-1 rounded-lg px-2 py-1 text-xs text-text-secondary hover:bg-surface"
              >
                {reveal ? <EyeOff size={14} /> : <Eye size={14} />}
                {reveal ? t('hideSecrets') : t('revealSecrets')}
              </button>
              <button
                onClick={() => copy(realCmd)}
                className="flex items-center gap-1 rounded-lg px-2 py-1 text-xs text-primary hover:bg-surface"
              >
                <Copy size={14} /> {t('copy')}
              </button>
            </div>
          </div>
          <div className="mt-2 flex items-start gap-1.5 text-xs text-text-secondary">
            <span>💡</span>
            {t('addDeviceTip')}
          </div>
        </>
      )}
    </Dialog>
  )
}
