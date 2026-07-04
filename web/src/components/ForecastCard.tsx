import { useEffect, useState } from 'react'
import { HardDrive, MemoryStick, TrendingUp } from 'lucide-react'
import { api } from '../lib/api'
import { useI18n } from '../lib/i18n'
import { projectToFull, type Forecast, type Point } from '../lib/forecast'

export function ForecastCard({ hostId }: { hostId: string }) {
  const { t } = useI18n()
  const [disk, setDisk] = useState<Forecast | null>(null)
  const [mem, setMem] = useState<Forecast | null>(null)

  useEffect(() => {
    let alive = true
    api
      .getHistory(168, hostId) // last 7 days
      .then((rows) => {
        if (!alive) return
        const toPts = (key: string): Point[] =>
          rows
            .map((r) => ({ t: Date.parse(String(r.ts)), y: Number(r[key]) }))
            .filter((p) => Number.isFinite(p.t) && Number.isFinite(p.y))
        setDisk(projectToFull(toPts('host_disk_max')))
        setMem(projectToFull(toPts('host_mem')))
      })
      .catch(() => {})
    return () => {
      alive = false
    }
  }, [hostId])

  // Nothing useful yet (fresh install with no history) → don't clutter.
  if (
    (!disk || disk.status === 'insufficient') &&
    (!mem || mem.status === 'insufficient')
  )
    return null

  return (
    <div className="card p-5">
      <div className="mb-4 flex items-center gap-3">
        <span className="grid h-9 w-9 place-items-center rounded-xl bg-primary/10 text-primary">
          <TrendingUp size={18} />
        </span>
        <div>
          <div className="text-sm font-semibold text-text-primary">{t('forecast')}</div>
          <div className="text-xs text-text-secondary">{t('digestRange')}</div>
        </div>
      </div>
      <div className="grid gap-3 sm:grid-cols-2">
        <Row icon={<HardDrive size={16} />} label={t('diskForecast')} f={disk} />
        <Row icon={<MemoryStick size={16} />} label={t('memForecast')} f={mem} />
      </div>
    </div>
  )
}

function Row({
  icon,
  label,
  f,
}: {
  icon: React.ReactNode
  label: string
  f: Forecast | null
}) {
  const { t } = useI18n()

  let badge = { text: t('needMoreData'), cls: 'bg-elevated text-text-secondary' }
  let sub: string | null = null

  if (f?.status === 'stable') {
    badge = { text: t('stableOrFalling'), cls: 'bg-accent/12 text-accent' }
    sub = t('projFrom').replace('{n}', String(f.samples))
  } else if (f?.status === 'filling' && f.etaMs != null) {
    const hours = f.etaMs / 3_600_000
    const text =
      hours >= 48
        ? t('fillsInDays').replace('{n}', String(Math.round(hours / 24)))
        : t('fillsInHours').replace('{n}', String(Math.max(1, Math.round(hours))))
    const urgent = hours < 72
    badge = { text, cls: urgent ? 'bg-danger/15 text-danger' : 'bg-warning/15 text-warning' }
    sub = t('projFrom').replace('{n}', String(f.samples))
  }

  return (
    <div className="flex items-center gap-3 rounded-xl border border-line/60 bg-bg/40 p-3">
      <span className="grid h-8 w-8 shrink-0 place-items-center rounded-lg bg-elevated text-text-secondary">
        {icon}
      </span>
      <div className="min-w-0 flex-1">
        <div className="text-sm font-medium text-text-primary">{label}</div>
        {sub && <div className="telemetry mt-0.5 truncate text-[11px] text-text-secondary">{sub}</div>}
      </div>
      <span className={`chip shrink-0 ${badge.cls}`}>
        {f?.current != null && (
          <span className="telemetry">{Math.round(f.current)}%</span>
        )}
        {badge.text}
      </span>
    </div>
  )
}
