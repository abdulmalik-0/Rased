import { BatteryCharging, Plug } from 'lucide-react'
import { useI18n } from '../lib/i18n'
import type { UpsStatus } from '../lib/types'

export function UpsCard({ ups }: { ups: UpsStatus }) {
  const { t } = useI18n()
  if (!ups.connected) return null
  const onBattery = ups.on_battery
  return (
    <div className="card flex items-center gap-3 p-4">
      <span
        className={`grid h-9 w-9 place-items-center rounded-xl ${
          onBattery ? 'bg-warning/10 text-warning' : 'bg-accent/10 text-accent'
        }`}
      >
        {onBattery ? <BatteryCharging size={18} /> : <Plug size={18} />}
      </span>
      <div className="flex-1">
        <div className="text-sm font-semibold text-text-primary">{t('upsTitle')}</div>
        <div className="text-xs text-text-secondary">
          {onBattery ? t('upsBattery') : t('upsOnline')}
        </div>
      </div>
      {ups.battery_charge_percent != null && (
        <span className="chip bg-elevated text-text-secondary">
          {t('battery')} {Math.round(ups.battery_charge_percent)}%
        </span>
      )}
    </div>
  )
}
