import { ProgressCircle } from '@tremor/react'

type Tone = 'teal' | 'amber' | 'red'

const clamp = (n: number) => Math.min(100, Math.max(0, n))
const toneText: Record<Tone, string> = {
  teal: 'text-teal-500 dark:text-teal-400',
  amber: 'text-amber-500 dark:text-amber-400',
  red: 'text-red-500 dark:text-red-400',
}
const toneGlow: Record<Tone, string> = {
  teal: 'glow-teal',
  amber: 'glow-amber',
  red: 'glow-red',
}

function statTone(pct: number): Tone {
  if (pct >= 90) return 'red'
  if (pct >= 75) return 'amber'
  return 'teal'
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
      <ProgressCircle
        value={clamp(percent)}
        color={tone}
        radius={45}
        strokeWidth={8}
        className={toneGlow[tone]}
      >
        <span className={`telemetry text-2xl font-semibold ${toneText[tone]}`}>
          {Math.round(percent)}%
        </span>
      </ProgressCircle>
      <div className="mt-2 text-center text-sm font-semibold text-text-primary">
        {label}
      </div>
      {detail ? (
        <div className="telemetry mt-0.5 text-center text-xs text-text-secondary">
          {detail}
        </div>
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
        : 'teal'
  return (
    <div
      className="flex w-16 flex-col items-center"
      title={`${label}: ${Math.round(current)}°C`}
    >
      <ProgressCircle
        value={clamp(current)}
        color={tone}
        radius={22}
        strokeWidth={4}
        className={toneGlow[tone]}
      >
        <span className={`telemetry text-xs font-semibold ${toneText[tone]}`}>
          {Math.round(current)}°
        </span>
      </ProgressCircle>
      <div className="mt-1 w-full truncate text-center text-[9px] text-text-secondary">
        {label}
      </div>
    </div>
  )
}
