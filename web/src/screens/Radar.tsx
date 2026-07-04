import { useCallback, useEffect, useMemo, useState } from 'react'
import { Radar as RadarIcon } from 'lucide-react'
import { DeviceSelector } from '../components/DeviceSelector'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { useI18n } from '../lib/i18n'
import { useMetrics } from '../lib/useMetrics'
import { deviceName, type ContainerMetrics, type Device } from '../lib/types'

const DEFAULT_DEVICE: Device = {
  host_id: 'default',
  host_name: 'My Server',
  display_name: '',
  api_url: '',
  nut_host: '',
  nut_ups_name: '',
}

type Tone = 'teal' | 'amber' | 'red'
const clamp = (n: number) => Math.min(100, Math.max(0, n))
const toneVar: Record<Tone, string> = {
  teal: 'var(--accent)',
  amber: 'var(--warning)',
  red: 'var(--danger)',
}

// Stable angle per container name so blips don't jump between frames.
function hashAngle(s: string): number {
  let h = 0
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0
  return h % 360
}

interface Blip {
  c: ContainerMetrics
  x: number
  y: number
  size: number
  tone: Tone
  alerted: boolean
}

function toBlips(containers: ContainerMetrics[], alerted: Set<string>): Blip[] {
  return containers.map((c) => {
    const down = c.status === 'exited' || c.status === 'dead'
    const isAlert = down || alerted.has(c.name)
    const cpu = clamp(c.cpu_percent)
    // Hot containers pull toward the core; down ones sit at the outer edge.
    const r = down ? 45 : 6 + 39 * (1 - cpu / 100)
    const a = ((hashAngle(c.name) - 90) * Math.PI) / 180
    const tone: Tone = isAlert
      ? 'red'
      : cpu >= 75 || c.memory_percent >= 85
        ? 'amber'
        : 'teal'
    return {
      c,
      x: 50 + r * Math.cos(a),
      y: 50 + r * Math.sin(a),
      size: 1.5 + (clamp(c.memory_percent) / 100) * 1.7,
      tone,
      alerted: isAlert,
    }
  })
}

export default function Radar() {
  const { session } = useAuth()
  const { t } = useI18n()
  const { metrics } = useMetrics(session?.token ?? null)
  const [table, setTable] = useState<Device[]>([])
  const [selected, setSelected] = useState<string | null>(null)
  const [hover, setHover] = useState<string | null>(null)

  const loadDevices = useCallback(() => {
    api.getDevices().then(setTable).catch(() => {})
  }, [])
  useEffect(loadDevices, [loadDevices])

  const devices = useMemo(() => {
    const byId: Record<string, Device> = {}
    for (const d of table) byId[d.host_id] = d
    for (const hostId of Object.keys(metrics)) {
      if (!byId[hostId])
        byId[hostId] = { ...DEFAULT_DEVICE, host_id: hostId, host_name: metrics[hostId].host_name }
    }
    const list = Object.values(byId)
    list.sort((a, b) => deviceName(a).localeCompare(deviceName(b)))
    return list.length ? list : [DEFAULT_DEVICE]
  }, [table, metrics])

  const active = devices.find((d) => d.host_id === selected) ?? devices[0] ?? DEFAULT_DEVICE
  const payload = metrics[active.host_id]
  const online = !!payload
  const liveIds = new Set(Object.keys(metrics))

  const alerted = useMemo(() => {
    const s = new Set<string>()
    for (const a of payload?.alerts ?? [])
      if (a.kind === 'container_down' || a.kind === 'anomaly') s.add(a.target)
    return s
  }, [payload])

  const blips = useMemo(
    () => toBlips(payload?.containers ?? [], alerted),
    [payload, alerted],
  )
  const contacts = useMemo(
    () => [...(payload?.containers ?? [])].sort((a, b) => b.cpu_percent - a.cpu_percent),
    [payload],
  )
  const counts = useMemo(() => {
    let crit = 0
    let warn = 0
    for (const b of blips) {
      if (b.tone === 'red') crit++
      else if (b.tone === 'amber') warn++
    }
    return { crit, warn, total: blips.length }
  }, [blips])

  // Labels only for the loudest contacts, so the scope stays readable.
  const labelled = new Set(contacts.slice(0, 6).map((c) => c.name))

  return (
    <div className="mx-auto max-w-[1500px] space-y-5 p-4 sm:p-6">
      <div className="flex flex-wrap items-center gap-3">
        <div>
          <div className="panel-label mb-1">{active.host_id}</div>
          <h1 className="text-2xl font-bold tracking-tight text-text-primary">
            {t('radar')}
          </h1>
          <p className="text-sm text-text-secondary">{deviceName(active)}</p>
        </div>
        <div className="ms-auto flex flex-wrap items-center gap-2">
          <span
            className={`chip uppercase ${online ? 'bg-accent/12 text-accent' : 'bg-danger/12 text-danger'}`}
          >
            <span className="relative grid h-1.5 w-1.5 place-items-center">
              <span className={`h-1.5 w-1.5 rounded-full ${online ? 'bg-accent' : 'bg-danger'}`} />
              {online && <span className="absolute h-1.5 w-1.5 rounded-full bg-accent animate-ping2" />}
            </span>
            {online ? t('agentOnline') : t('agentOffline')}
          </span>
          <DeviceSelector
            devices={devices}
            liveIds={liveIds}
            selected={active.host_id}
            onSelect={setSelected}
          />
        </div>
      </div>

      {!online ? (
        <div className="card grid place-items-center gap-3 py-24 text-text-secondary">
          <RadarIcon className="animate-pulse text-primary" size={28} />
          {t('noSignal')}
        </div>
      ) : (
        <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_320px]">
          {/* The scope */}
          <div className="card relative overflow-hidden p-4 sm:p-6">
            <div className="mb-4 flex flex-wrap items-center gap-2">
              <span className="chip bg-accent/12 text-accent">
                {counts.total} {t('contacts')}
              </span>
              {counts.warn > 0 && (
                <span className="chip bg-warning/15 text-warning">
                  {counts.warn} {t('elevated')}
                </span>
              )}
              {counts.crit > 0 && (
                <span className="chip bg-danger/15 text-danger">
                  {counts.crit} {t('critical')}
                </span>
              )}
            </div>
            <div className="mx-auto aspect-square w-full max-w-[560px]">
              <Scope blips={blips} labelled={labelled} hover={hover} onHover={setHover} />
            </div>
          </div>

          {/* Contacts list */}
          <div className="card flex flex-col p-0">
            <div className="panel-label border-b border-line/60 px-4 py-3">
              {t('contacts')}
            </div>
            {contacts.length === 0 ? (
              <div className="p-4 text-sm text-text-secondary">{t('noContainers')}</div>
            ) : (
              <ul className="divide-y divide-line/50 overflow-y-auto">
                {contacts.map((c) => {
                  const down = c.status === 'exited' || c.status === 'dead'
                  const tone: Tone = down || alerted.has(c.name)
                    ? 'red'
                    : c.cpu_percent >= 75 || c.memory_percent >= 85
                      ? 'amber'
                      : 'teal'
                  return (
                    <li
                      key={c.id}
                      onMouseEnter={() => setHover(c.name)}
                      onMouseLeave={() => setHover(null)}
                      className={`flex items-center gap-2.5 px-4 py-2.5 transition ${
                        hover === c.name ? 'bg-elevated' : ''
                      }`}
                    >
                      <span
                        className="h-2 w-2 shrink-0 rounded-full"
                        style={{ background: toneVar[tone], boxShadow: `0 0 6px ${toneVar[tone]}` }}
                      />
                      <span className="flex-1 truncate text-sm text-text-primary" title={c.name}>
                        {c.name}
                      </span>
                      <span className="telemetry text-xs text-text-secondary">
                        {c.cpu_percent.toFixed(0)}%
                      </span>
                    </li>
                  )
                })}
              </ul>
            )}
          </div>
        </div>
      )}
    </div>
  )
}

function Scope({
  blips,
  labelled,
  hover,
  onHover,
}: {
  blips: Blip[]
  labelled: Set<string>
  hover: string | null
  onHover: (name: string | null) => void
}) {
  return (
    <svg viewBox="0 0 100 100" className="h-full w-full select-none" fill="none">
      <defs>
        <radialGradient id="scope-bg" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="rgb(var(--primary))" stopOpacity="0.10" />
          <stop offset="100%" stopColor="rgb(var(--primary))" stopOpacity="0" />
        </radialGradient>
        <linearGradient id="scope-sweep" x1="50%" y1="50%" x2="100%" y2="0%">
          <stop offset="0%" stopColor="rgb(var(--primary))" stopOpacity="0.35" />
          <stop offset="100%" stopColor="rgb(var(--primary))" stopOpacity="0" />
        </linearGradient>
      </defs>

      <circle cx="50" cy="50" r="46" fill="url(#scope-bg)" />
      {[11.5, 23, 34.5, 46].map((r) => (
        <circle key={r} cx="50" cy="50" r={r} stroke="rgb(var(--primary))" strokeOpacity="0.16" strokeWidth="0.3" />
      ))}
      <line x1="4" y1="50" x2="96" y2="50" stroke="rgb(var(--primary))" strokeOpacity="0.12" strokeWidth="0.3" />
      <line x1="50" y1="4" x2="50" y2="96" stroke="rgb(var(--primary))" strokeOpacity="0.12" strokeWidth="0.3" />

      {/* rotating sweep */}
      <g className="animate-sweep" style={{ transformBox: 'view-box', transformOrigin: '50px 50px' }}>
        <path d="M50 50 L50 4 A46 46 0 0 1 96 50 Z" fill="url(#scope-sweep)" />
        <line x1="50" y1="50" x2="50" y2="4" stroke="rgb(var(--primary))" strokeOpacity="0.5" strokeWidth="0.4" />
      </g>

      {blips.map((b) => {
        const active = hover === b.c.name
        const color = toneVar[b.tone]
        return (
          <g
            key={b.c.id}
            onMouseEnter={() => onHover(b.c.name)}
            onMouseLeave={() => onHover(null)}
            style={{ cursor: 'pointer' }}
          >
            {b.alerted && (
              <circle cx={b.x} cy={b.y} r={b.size} fill="none" stroke={color} strokeWidth="0.4">
                <animate attributeName="r" from={b.size} to={b.size + 4} dur="1.6s" repeatCount="indefinite" />
                <animate attributeName="opacity" from="0.7" to="0" dur="1.6s" repeatCount="indefinite" />
              </circle>
            )}
            <circle
              cx={b.x}
              cy={b.y}
              r={active ? b.size + 0.8 : b.size}
              fill={color}
              style={{ filter: `drop-shadow(0 0 ${active ? 3 : 1.6}px ${color})`, transition: 'r .1s' }}
            >
              <title>{`${b.c.name} — CPU ${b.c.cpu_percent.toFixed(0)}% · RAM ${b.c.memory_percent.toFixed(0)}%`}</title>
            </circle>
            {(labelled.has(b.c.name) || active) && (
              <text
                x={b.x}
                y={b.y - b.size - 1.2}
                textAnchor="middle"
                fontSize="2.6"
                className="telemetry"
                fill="rgb(var(--text-secondary))"
              >
                {b.c.name.length > 14 ? b.c.name.slice(0, 13) + '…' : b.c.name}
              </text>
            )}
          </g>
        )
      })}
    </svg>
  )
}
