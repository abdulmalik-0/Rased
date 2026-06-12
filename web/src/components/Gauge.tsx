import { ProgressCircle } from '@tremor/react'

type Tone = 'emerald' | 'amber' | 'red'

const clamp = (n: number) => Math.min(100, Math.max(0, n))
const toneText: Record<Tone, string> = {
  emerald: 'text-emerald-500',
  amber: 'text-amber-500',
  red: 'text-red-500',
}

function statTone(pct: number): Tone {
  if (pct >= 90) return 'red'
  if (pct >= 75) return 'amber'
  return 'emerald'
}

export function StatGauge({
  label,
  percent,
  detail,
}: {
  label: string
  percent: number
  detail?: string
}) {
  const tone = statTone(percent)
  return (
    <div className="flex w-32 flex-col items-center">
      <ProgressCircle value={clamp(percent)} color={tone} radius={45} strokeWidth={8}>
        <span className={`text-2xl font-bold ${toneText[tone]}`}>
          {Math.round(percent)}%
        </span>
      </ProgressCircle>
      <div className="mt-2 text-center text-sm font-semibold text-text-primary">
        {label}
      </div>
      {detail ? (
        <div className="text-center text-xs text-text-secondary">{detail}</div>
      ) : null}
    </div>
  )
}

export function TempGauge({
  label,
  current,
  high,
}: {
  label: string
  current: number
  high: number | null
}) {
  const tone: Tone =
    (high != null ? current >= high : current >= 80)
      ? 'red'
      : current >= 65
        ? 'amber'
        : 'emerald'
  return (
    <div
      className="flex w-16 flex-col items-center"
      title={`${label}: ${Math.round(current)}°C`}
    >
      <ProgressCircle value={clamp(current)} color={tone} radius={22} strokeWidth={4}>
        <span className={`text-xs font-bold ${toneText[tone]}`}>
          {Math.round(current)}°
        </span>
      </ProgressCircle>
      <div className="mt-1 w-full truncate text-center text-[9px] text-text-secondary">
        {label}
      </div>
    </div>
  )
}
