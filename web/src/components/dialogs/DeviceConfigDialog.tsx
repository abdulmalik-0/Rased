import { useState } from 'react'
import { Settings2 } from 'lucide-react'
import { Dialog } from '../Dialog'
import { Field, GhostButton, PrimaryButton } from '../Field'
import { api } from '../../lib/api'
import { useI18n } from '../../lib/i18n'
import { deviceName, type Device } from '../../lib/types'

export function DeviceConfigDialog({
  open,
  onClose,
  device,
  onSaved,
}: {
  open: boolean
  onClose: () => void
  device: Device
  onSaved: () => void
}) {
  const { t } = useI18n()
  const [name, setName] = useState(device.display_name || '')
  const [nutHost, setNutHost] = useState(device.nut_host || '')
  const [nutUps, setNutUps] = useState(device.nut_ups_name || '')
  const [busy, setBusy] = useState(false)

  async function save() {
    setBusy(true)
    try {
      await api.updateDevice(device.host_id, {
        display_name: name.trim(),
        nut_host: nutHost.trim(),
        nut_ups_name: nutUps.trim(),
      })
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
      icon={<Settings2 className="text-primary" size={18} />}
      title={`${t('deviceSettings')} — ${deviceName(device)}`}
    >
      <div className="space-y-3">
        <Field
          label={t('displayName')}
          value={name}
          onChange={setName}
          placeholder={device.host_name}
        />
        <Field
          label={t('nutHost')}
          value={nutHost}
          onChange={setNutHost}
          placeholder="192.168.100.89"
          dir="ltr"
        />
        <Field label={t('nutUpsName')} value={nutUps} onChange={setNutUps} placeholder="tecnoware" dir="ltr" />
      </div>
      <div className="mt-5 flex items-center justify-end gap-2">
        <GhostButton onClick={onClose}>{t('cancel')}</GhostButton>
        <PrimaryButton onClick={save} disabled={busy}>
          {t('save')}
        </PrimaryButton>
      </div>
    </Dialog>
  )
}
