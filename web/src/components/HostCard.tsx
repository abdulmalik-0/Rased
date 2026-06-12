import { Cpu, Gauge } from 'lucide-react'
import { useI18n } from '../lib/i18n'
import type { HostStats } from '../lib/types'
import { StatGauge, TempGauge } from './Gauge'

export function HostCard({ host, name }: { host: HostStats; name: string }) {
  const { t } = useI18n()
  return (
    <div className="card p-5">
      <div className="mb-5 flex items-center gap-3">
        <span className="grid h-9 w-9 place-items-center rounded-xl bg-primary/10 text-primary">
          <Cpu size={18} />
        </span>
        <div className="flex-1">
          <div className="text-sm font-semibold text-text-primary">
            {t('hostTitle')}
          </div>
          <div className="text-xs text-text-secondary">{name}</div>
        </div>
        {host.load_avg_1m != null && (
          <span className="chip bg-elevated text-text-secondary">
            <Gauge size={13} /> {t('load')} {host.load_avg_1m.toFixed(2)}
          </span>
        )}
      </div>

      {!host.available ? (
        <div className="text-sm text-text-secondary">
          {host.error ?? t('hostUnavailable')}
        </div>
      ) : (
        <>
          <div className="flex flex-wrap justify-center gap-6 sm:justify-start">
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
            <div className="mt-5 border-t border-line/60 pt-4">
              <div className="mb-3 text-xs font-medium uppercase tracking-wide text-text-secondary">
                {t('temperatures')}
              </div>
              <div className="flex flex-wrap gap-4">
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
