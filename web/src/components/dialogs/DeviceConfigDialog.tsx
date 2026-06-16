import { useEffect, useState } from 'react'
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
  const [thr, setThr] = useState({ cpu: '', mem: '', disk: '', battery: '' })
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    if (!open) return
    api
      .getThresholds(device.host_id)
      .then((x) =>
        setThr({
          cpu: x.cpu != null ? String(x.cpu) : '',
          mem: x.mem != null ? String(x.mem) : '',
          disk: x.disk != null ? String(x.disk) : '',
          battery: x.battery != null ? String(x.battery) : '',
        }),
      )
      .catch(() => {})
  }, [open, device.host_id])

  const num = (s: string) => (s.trim() === '' ? null : Number(s))

  async function save() {
    setBusy(true)
    try {
      await api.updateDevice(device.host_id, {
        display_name: name.trim(),
        nut_host: nutHost.trim(),
        nut_ups_name: nutUps.trim(),
      })
      await api.setThresholds({
        host_id: device.host_id,
        cpu: num(thr.cpu),
        mem: num(thr.mem),
        disk: num(thr.disk),
        battery: num(thr.battery),
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
        <Field label={t('displayName')} value={name} onChange={setName} placeholder={device.host_name} />
        <Field label={t('nutHost')} value={nutHost} onChange={setNutHost} placeholder="192.168.100.89" dir="ltr" />
        <Field label={t('nutUpsName')} value={nutUps} onChange={setNutUps} placeholder="tecnoware" dir="ltr" />
      </div>

      <div className="mt-5 border-t border-line/60 pt-4">
        <div className="mb-1 text-sm font-semibold text-text-primary">{t('thresholds')}</div>
        <div className="mb-3 text-xs text-text-secondary">{t('thresholdsHint')}</div>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <Field label={`${t('hostCpu')} %`} value={thr.cpu} onChange={(v) => setThr({ ...thr, cpu: v })} type="number" dir="ltr" />
          <Field label={`${t('hostMemory')} %`} value={thr.mem} onChange={(v) => setThr({ ...thr, mem: v })} type="number" dir="ltr" />
          <Field label={`${t('disk')} %`} value={thr.disk} onChange={(v) => setThr({ ...thr, disk: v })} type="number" dir="ltr" />
          <Field label={`${t('battery')} %`} value={thr.battery} onChange={(v) => setThr({ ...thr, battery: v })} type="number" dir="ltr" />
        </div>
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
