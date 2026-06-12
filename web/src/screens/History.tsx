import { useEffect, useState } from 'react'
import { AreaChart } from '@tremor/react'
import { Loader2 } from 'lucide-react'
import { api } from '../lib/api'
import { useI18n } from '../lib/i18n'

const RANGES = [
  { key: 'range24h', hours: 24 },
  { key: 'range7d', hours: 168 },
  { key: 'range30d', hours: 720 },
]

interface Point {
  time: string
  [k: string]: string | number
}

export default function History() {
  const { t } = useI18n()
  const [hours, setHours] = useState(24)
  const [data, setData] = useState<Point[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let ignore = false
    setLoading(true)
    setError(null)
    api
      .getHistory(hours)
      .then((rows) => {
        if (ignore) return
        const fmt = (iso: string) => {
          const d = new Date(iso)
          return hours <= 24
            ? d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
            : d.toLocaleDateString([], { month: 'short', day: 'numeric' })
        }
        setData(
          rows.map((r) => ({
            time: fmt(String(r.ts ?? r.time ?? '')),
            [t('cpuPct')]: round(r.host_cpu),
            [t('memPct')]: round(r.host_memory),
            [t('diskPct')]: round(r.host_disk),
          })),
        )
      })
      .catch((e) => !ignore && setError(e instanceof Error ? e.message : t('historyError')))
      .finally(() => !ignore && setLoading(false))
    return () => {
      ignore = true
    }
  }, [hours, t])

  return (
    <div className="mx-auto max-w-5xl space-y-5 p-4 sm:p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-xl font-bold tracking-tight text-text-primary">
          {t('history')}
        </h1>
        <div className="flex rounded-xl border border-line/70 bg-surface p-0.5">
          {RANGES.map((r) => (
            <button
              key={r.hours}
              onClick={() => setHours(r.hours)}
              className={`rounded-lg px-3 py-1.5 text-sm font-medium transition ${
                hours === r.hours
                  ? 'bg-primary text-white'
                  : 'text-text-secondary hover:text-text-primary'
              }`}
            >
              {t(r.key)}
            </button>
          ))}
        </div>
      </div>

      <div className="card p-5">
        {loading ? (
          <div className="grid place-items-center py-16">
            <Loader2 className="animate-spin text-primary" size={26} />
          </div>
        ) : error ? (
          <div className="py-10 text-center text-sm text-danger">{error}</div>
        ) : data.length === 0 ? (
          <div className="py-16 text-center text-text-secondary">{t('noHistory')}</div>
        ) : (
          <AreaChart
            className="h-80"
            data={data}
            index="time"
            categories={[t('cpuPct'), t('memPct'), t('diskPct')]}
            colors={['blue', 'emerald', 'amber']}
            valueFormatter={(v) => `${v}%`}
            showAnimation
            yAxisWidth={40}
            maxValue={100}
          />
        )}
      </div>
    </div>
  )
}

function round(v: unknown): number {
  const n = typeof v === 'number' ? v : Number(v)
  return Number.isFinite(n) ? Math.round(n) : 0
}
