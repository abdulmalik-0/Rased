import { useState } from 'react'
import { ChevronDown, Server } from 'lucide-react'
import { deviceName, type Device } from '../lib/types'

export function DeviceSelector({
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
  const [open, setOpen] = useState(false)
  const active = devices.find((d) => d.host_id === selected) ?? devices[0]
  const dot = (id: string) =>
    liveIds.has(id) ? 'bg-accent shadow-[0_0_8px] shadow-accent/60' : 'bg-text-secondary'

  if (devices.length < 2) {
    return (
      <div className="flex items-center gap-2 rounded-xl border border-line/70 bg-surface px-3 py-1.5 text-sm font-medium text-text-primary">
        <Server size={15} className="text-text-secondary" />
        {deviceName(active)}
        <span className={`h-2 w-2 rounded-full ${dot(active.host_id)}`} />
      </div>
    )
  }

  return (
    <div className="relative">
      <button
        onClick={() => setOpen((o) => !o)}
        className="flex items-center gap-2 rounded-xl border border-line/70 bg-surface px-3 py-1.5 text-sm font-medium text-text-primary transition hover:bg-elevated"
      >
        <Server size={15} className="text-text-secondary" />
        {deviceName(active)}
        <span className={`h-2 w-2 rounded-full ${dot(active.host_id)}`} />
        <ChevronDown size={14} className="text-text-secondary" />
      </button>
      {open && (
        <>
          <div className="fixed inset-0 z-10" onClick={() => setOpen(false)} />
          <div className="absolute start-0 z-20 mt-1.5 w-56 animate-fade-in overflow-hidden rounded-xl border border-line/70 bg-surface py-1 shadow-cardHover">
            {devices.map((d) => (
              <button
                key={d.host_id}
                onClick={() => {
                  onSelect(d.host_id)
                  setOpen(false)
                }}
                className={`flex w-full items-center gap-2.5 px-3 py-2 text-start text-sm transition hover:bg-elevated ${
                  d.host_id === active.host_id
                    ? 'text-primary'
                    : 'text-text-primary'
                }`}
              >
                <span className={`h-2 w-2 shrink-0 rounded-full ${dot(d.host_id)}`} />
                <span className="flex-1 truncate">{deviceName(d)}</span>
              </button>
            ))}
          </div>
        </>
      )}
    </div>
  )
}
