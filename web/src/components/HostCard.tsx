import { Cpu } from 'lucide-react'
import { useI18n } from '../lib/i18n'
import type { HostStats } from '../lib/types'
import { StatGauge, TempGauge } from './Gauge'

export function HostCard({ host, name }: { host: HostStats; name: string }) {
  const { t } = useI18n()
  return (
    <div className="rounded-xl border border-line bg-surface p-4">
      <div className="mb-4 flex items-center gap-2">
        <Cpu className="text-primary" size={18} />
        <span className="font-semibold text-text-primary">
          {t('hostTitle')} · {name}
        </span>
        {host.load_avg_1m != null && (
          <span className="ms-auto text-xs text-text-secondary">
            {t('load')}: {host.load_avg_1m.toFixed(2)}
          </span>
        )}
      </div>

      {!host.available ? (
        <div className="text-sm text-text-secondary">
          {host.error ?? t('hostUnavailable')}
        </div>
      ) : (
        <>
          <div className="flex flex-wrap gap-5">
            <StatGauge
              label={t('hostCpu')}
              percent={host.cpu_percent}
              detail={host.cpu_cores > 0 ? `${host.cpu_cores} ${t('cores')}` : undefined}
            />
            <StatGauge
              label={t('hostMemory')}
              percent={host.memory_percent}
              detail={`${(host.memory_used_mb / 1024).toFixed(1)} / ${(host.memory_total_mb / 1024).toFixed(1)} GB`}
            />
            {host.disks.map((d) => (
              <StatGauge
                key={d.mount}
                label={`${t('disk')} ${d.mount}`}
                percent={d.percent}
                detail={`${d.used_gb.toFixed(0)} / ${d.total_gb.toFixed(0)} GB`}
              />
            ))}
          </div>

          {host.temperatures.length > 0 && (
            <div className="mt-4">
              <div className="mb-2 text-xs text-text-secondary">
                {t('temperatures')}
              </div>
              <div className="flex flex-wrap gap-3">
                {host.temperatures.map((tp) => (
                  <TempGauge
                    key={tp.label}
                    label={tp.label}
                    current={tp.current}
                    high={tp.high}
                  />
                ))}
              </div>
            </div>
          )}
        </>
      )}
    </div>
  )
}
