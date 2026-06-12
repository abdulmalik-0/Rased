import { BatteryCharging, Plug } from 'lucide-react'
import { useI18n } from '../lib/i18n'
import type { UpsStatus } from '../lib/types'

export function UpsCard({ ups }: { ups: UpsStatus }) {
  const { t } = useI18n()
  if (!ups.connected) return null
  const onBattery = ups.on_battery
  return (
    <div className="flex items-center gap-3 rounded-xl border border-line bg-surface p-4">
      {onBattery ? (
        <BatteryCharging className="text-warning" />
      ) : (
        <Plug className="text-accent" />
      )}
      <div>
        <div className="font-semibold text-text-primary">{t('upsTitle')}</div>
        <div className="text-sm text-text-secondary">
          {onBattery ? t('upsBattery') : t('upsOnline')}
          {ups.battery_charge_percent != null &&
            ` · ${t('battery')} ${Math.round(ups.battery_charge_percent)}%`}
        </div>
      </div>
    </div>
  )
}
