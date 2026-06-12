import { useEffect, useMemo, useState } from 'react'
import { AlertsCard } from '../components/AlertsCard'
import { ContainerCard } from '../components/ContainerCard'
import { DeviceTabs } from '../components/DeviceTabs'
import { HostCard } from '../components/HostCard'
import { Topbar } from '../components/Topbar'
import { UpsCard } from '../components/UpsCard'
import { api } from '../lib/api'
import { backendUrl } from '../lib/config'
import { useAuth } from '../lib/auth'
import { useI18n } from '../lib/i18n'
import { useToast } from '../lib/toast'
import { useMetrics } from '../lib/useMetrics'
import { deviceName, isAdmin, type Device } from '../lib/types'

const DEFAULT_DEVICE: Device = {
  host_id: 'default',
  host_name: 'My Server',
  display_name: '',
  api_url: '',
  nut_host: '',
  nut_ups_name: '',
}

export default function Dashboard() {
  const { session } = useAuth()
  const { t } = useI18n()
  const toast = useToast()
  const admin = isAdmin(session)
  const { metrics, refresh } = useMetrics(session?.token ?? null)

  const [table, setTable] = useState<Device[]>([])
  const [selected, setSelected] = useState<string | null>(null)
  const [links, setLinks] = useState<Record<string, { url: string; label: string }>>({})

  useEffect(() => {
    api.getDevices().then(setTable).catch(() => {})
  }, [])

  const devices = useMemo(() => {
    const byId: Record<string, Device> = {}
    for (const d of table) byId[d.host_id] = d
    for (const hostId of Object.keys(metrics)) {
      if (!byId[hostId])
        byId[hostId] = {
          ...DEFAULT_DEVICE,
          host_id: hostId,
          host_name: metrics[hostId].host_name,
        }
    }
    const list = Object.values(byId)
    list.sort((a, b) => deviceName(a).localeCompare(deviceName(b)))
    return list.length ? list : [DEFAULT_DEVICE]
  }, [table, metrics])

  const active =
    devices.find((d) => d.host_id === selected) ?? devices[0] ?? DEFAULT_DEVICE
  const apiUrl = active.api_url || backendUrl
  const payload = metrics[active.host_id]
  const online = !!payload

  useEffect(() => {
    api
      .getLinks(active.host_id)
      .then((rows) => {
        const map: Record<string, { url: string; label: string }> = {}
        for (const r of rows)
          map[String(r.name)] = { url: String(r.url ?? ''), label: String(r.label ?? '') }
        setLinks(map)
      })
      .catch(() => setLinks({}))
  }, [active.host_id])

  async function handleAction(containerId: string, action: string) {
    if (action === 'logs') {
      toast('Logs viewer — coming in the next phase')
      return
    }
    if (!window.confirm(`${t(action)}?`)) return
    try {
      await api.containerAction(containerId, action, apiUrl)
      toast('OK')
      refresh()
    } catch (e) {
      toast(e instanceof Error ? e.message : 'Error')
    }
  }

  const liveIds = new Set(Object.keys(metrics))

  return (
    <div className="flex h-full flex-col">
      <Topbar online={online} onRefresh={refresh} />
      <DeviceTabs
        devices={devices}
        liveIds={liveIds}
        selected={active.host_id}
        onSelect={setSelected}
      />

      <div className="flex-1 overflow-y-auto p-4">
        {!payload ? (
          <div className="flex h-full items-center justify-center text-text-secondary">
            {t('waitingMetrics')}
          </div>
        ) : (
          <div className="mx-auto max-w-[1400px] space-y-4">
            <HostCard host={payload.host} name={deviceName(active)} />
            <AlertsCard alerts={payload.alerts} />
            <UpsCard ups={payload.ups} />

            {payload.containers.length === 0 ? (
              <div className="py-10 text-center text-text-secondary">
                {t('noContainers')}
              </div>
            ) : (
              <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
                {payload.containers.map((c) => (
                  <ContainerCard
                    key={c.id}
                    container={c}
                    apiUrl={apiUrl}
                    isAdmin={admin}
                    customLink={links[c.name]}
                    onAction={(a) => handleAction(c.id, a)}
                  />
                ))}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
