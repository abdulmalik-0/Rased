import { useState } from 'react'
import { Link2 } from 'lucide-react'
import { Dialog } from '../Dialog'
import { Field, GhostButton, PrimaryButton } from '../Field'
import { api } from '../../lib/api'
import { useI18n } from '../../lib/i18n'

export function LinkEditDialog({
  open,
  onClose,
  hostId,
  containerName,
  initial,
  onSaved,
}: {
  open: boolean
  onClose: () => void
  hostId: string
  containerName: string
  initial?: { url: string; label: string }
  onSaved: () => void
}) {
  const { t } = useI18n()
  const [url, setUrl] = useState(initial?.url ?? '')
  const [label, setLabel] = useState(initial?.label ?? '')
  const [busy, setBusy] = useState(false)

  async function save(remove = false) {
    setBusy(true)
    try {
      if (remove || !url.trim()) await api.deleteLink(hostId, containerName)
      else await api.setLink(hostId, containerName, url.trim(), label.trim())
      onSaved()
      onClose()
    } catch {
      /* ignore */
    } finally {
      setBusy(false)
    }
  }

  return (
    <Dialog
      open={open}
      onClose={onClose}
      icon={<Link2 className="text-primary" size={18} />}
      title={`${t('customLink')} — ${containerName}`}
    >
      <div className="space-y-3">
        <Field
          label={t('linkUrl')}
          value={url}
          onChange={setUrl}
          placeholder="http://192.168.100.100:8080"
          dir="ltr"
        />
        <Field label={t('linkLabel')} value={label} onChange={setLabel} placeholder="Web UI" />
      </div>
      <div className="mt-5 flex items-center justify-end gap-2">
        {initial?.url && <GhostButton onClick={() => save(true)}>{t('remove')}</GhostButton>}
        <GhostButton onClick={onClose}>{t('cancel')}</GhostButton>
        <PrimaryButton onClick={() => save()} disabled={busy}>
          {t('save')}
        </PrimaryButton>
      </div>
    </Dialog>
  )
}
