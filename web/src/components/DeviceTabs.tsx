import { deviceName, type Device } from '../lib/types'

export function DeviceTabs({
  devices,
  liveIds,
  selected,
  onSelect,
}: {
  devices: Device[]
  liveIds: Set<string>
  selected: string
  onSelect: (hostId: string) => void
}) {
  if (devices.length < 2) return null
  return (
    <div className="flex gap-2 overflow-x-auto border-b border-line bg-surface px-3 py-2">
      {devices.map((d) => {
        const active = d.host_id === selected
        const live = liveIds.has(d.host_id)
        return (
          <button
            key={d.host_id}
            onClick={() => onSelect(d.host_id)}
            className={`flex shrink-0 items-center gap-2 rounded-full border px-3 py-1 text-sm transition ${
              active
                ? 'border-primary bg-primary/15 text-text-primary'
                : 'border-line text-text-secondary hover:bg-elevated'
            }`}
          >
            <span
              className={`h-2 w-2 rounded-full ${live ? 'bg-accent' : 'bg-text-secondary'}`}
            />
            {deviceName(d)}
          </button>
        )
      })}
    </div>
  )
}
