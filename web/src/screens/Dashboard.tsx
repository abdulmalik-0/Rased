import { useCallback, useEffect, useMemo, useState } from 'react'
import { Loader2, PlusSquare, RefreshCw, Rocket, Settings2 } from 'lucide-react'
import { AlertsCard } from '../components/AlertsCard'
import { ContainerCard } from '../components/ContainerCard'
import { DeviceSelector } from '../components/DeviceSelector'
import { HostCard } from '../components/HostCard'
import { UpsCard } from '../components/UpsCard'
import { AddDeviceDialog } from '../components/dialogs/AddDeviceDialog'
import { DeployDialog } from '../components/dialogs/DeployDialog'
import { DeviceConfigDialog } from '../components/dialogs/DeviceConfigDialog'
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
  const [addOpen, setAddOpen] = useState(false)
  const [cfgOpen, setCfgOpen] = useState(false)
  const [deployOpen, setDeployOpen] = useState(false)

  const loadDevices = useCallback(() => {
    api.getDevices().then(setTable).catch(() => {})
  }, [])
  useEffect(loadDevices, [loadDevices])

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

  const loadLinks = useCallback(() => {
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
  useEffect(loadLinks, [loadLinks])

  async function handleAction(containerId: string, action: string) {
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
    <div className="mx-auto max-w-[1500px] space-y-5 p-4 sm:p-6">
      <div className="flex flex-wrap items-center gap-3">
        <div>
          <h1 className="text-xl font-bold tracking-tight text-text-primary">
            {t('overview')}
          </h1>
          <p className="text-sm text-text-secondary">{deviceName(active)}</p>
        </div>
        <div className="ms-auto flex flex-wrap items-center gap-2">
          <span
            className={`chip ${online ? 'bg-accent/12 text-accent' : 'bg-danger/12 text-danger'}`}
          >
            <span
              className={`h-1.5 w-1.5 rounded-full ${online ? 'bg-accent' : 'bg-danger'}`}
            />
            {online ? t('agentOnline') : t('agentOffline')}
          </span>
          <DeviceSelector
            devices={devices}
            liveIds={liveIds}
            selected={active.host_id}
            onSelect={setSelected}
          />
          {admin && (
            <>
              <IconBtn title={t('deviceSettings')} onClick={() => setCfgOpen(true)}>
                <Settings2 size={16} />
              </IconBtn>
              <IconBtn title={t('addDevice')} onClick={() => setAddOpen(true)}>
                <PlusSquare size={16} />
              </IconBtn>
              <IconBtn title={t('deployTitle')} onClick={() => setDeployOpen(true)}>
                <Rocket size={16} />
              </IconBtn>
            </>
          )}
          <IconBtn title={t('refresh')} onClick={refresh}>
            <RefreshCw size={16} />
          </IconBtn>
        </div>
      </div>

      {!payload ? (
        <div className="card grid place-items-center gap-3 py-20 text-text-secondary">
          <Loader2 className="animate-spin text-primary" size={28} />
          {t('waitingMetrics')}
        </div>
      ) : (
        <div className="animate-fade-in space-y-5">
          <HostCard host={payload.host} name={deviceName(active)} />
          <AlertsCard alerts={payload.alerts} />
          <UpsCard ups={payload.ups} />

          {payload.containers.length === 0 ? (
            <div className="card py-12 text-center text-text-secondary">
              {t('noContainers')}
            </div>
          ) : (
            <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
              {payload.containers.map((c) => (
                <ContainerCard
                  key={c.id}
                  container={c}
                  apiUrl={apiUrl}
                  hostId={active.host_id}
                  isAdmin={admin}
                  customLink={links[c.name]}
                  onAction={(a) => handleAction(c.id, a)}
                  reloadLinks={loadLinks}
                />
              ))}
            </div>
          )}
        </div>
      )}

      <AddDeviceDialog open={addOpen} onClose={() => setAddOpen(false)} />
      <DeployDialog open={deployOpen} onClose={() => setDeployOpen(false)} />
      {cfgOpen && (
        <DeviceConfigDialog
          open={cfgOpen}
          onClose={() => setCfgOpen(false)}
          device={active}
          onSaved={loadDevices}
        />
      )}
    </div>
  )
}

function IconBtn(props: {
  title: string
  onClick: () => void
  children: React.ReactNode
}) {
  return (
    <button
      title={props.title}
      onClick={props.onClick}
      className="btn-ghost border border-line/70 bg-surface"
    >
      {props.children}
    </button>
  )
}
