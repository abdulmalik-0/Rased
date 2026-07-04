import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { useNavigate } from 'react-router-dom'
import {
  Bell,
  Box,
  CornerDownLeft,
  HelpCircle,
  LayoutDashboard,
  LineChart,
  MessageSquare,
  Radar,
  Search,
  Server,
  Settings as SettingsIcon,
  Users as UsersIcon,
} from 'lucide-react'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { useI18n } from '../lib/i18n'
import { deviceName, isAdmin, type Device, type MetricsPayload } from '../lib/types'

interface Item {
  id: string
  group: string
  label: string
  sub?: string
  icon: ReactNode
  run: () => void
}

export function CommandPalette({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { t } = useI18n()
  const { session } = useAuth()
  const nav = useNavigate()
  const admin = isAdmin(session)
  const [q, setQ] = useState('')
  const [active, setActive] = useState(0)
  const [devices, setDevices] = useState<Device[]>([])
  const [payloads, setPayloads] = useState<MetricsPayload[]>([])
  const inputRef = useRef<HTMLInputElement>(null)
  const listRef = useRef<HTMLDivElement>(null)

  // Load live data each time it opens (cheap, and always current).
  useEffect(() => {
    if (!open) return
    setQ('')
    setActive(0)
    api.getDevices().then(setDevices).catch(() => {})
    api.getMetricsAll().then(setPayloads).catch(() => {})
    const id = setTimeout(() => inputRef.current?.focus(), 20)
    return () => clearTimeout(id)
  }, [open])

  const items = useMemo<Item[]>(() => {
    const go = (to: string) => () => {
      onClose()
      nav(to)
    }
    const screens: Item[] = [
      { id: 's-dash', group: t('cmdkScreens'), label: t('dashboard'), icon: <LayoutDashboard size={16} />, run: go('/') },
      { id: 's-radar', group: t('cmdkScreens'), label: t('radar'), icon: <Radar size={16} />, run: go('/radar') },
      { id: 's-alerts', group: t('cmdkScreens'), label: t('alertsScreen'), icon: <Bell size={16} />, run: go('/alerts') },
      { id: 's-hist', group: t('cmdkScreens'), label: t('history'), icon: <LineChart size={16} />, run: go('/history') },
      { id: 's-chat', group: t('cmdkScreens'), label: t('askAi'), icon: <MessageSquare size={16} />, run: go('/chat') },
      { id: 's-set', group: t('cmdkScreens'), label: t('settings'), icon: <SettingsIcon size={16} />, run: go('/settings') },
      ...(admin
        ? [{ id: 's-users', group: t('cmdkScreens'), label: t('users'), icon: <UsersIcon size={16} />, run: go('/users') }]
        : []),
      { id: 's-help', group: t('cmdkScreens'), label: t('help'), icon: <HelpCircle size={16} />, run: go('/help') },
    ]
    const devs: Item[] = devices.map((d) => ({
      id: `d-${d.host_id}`,
      group: t('cmdkDevices'),
      label: deviceName(d),
      sub: d.host_id,
      icon: <Server size={16} />,
      run: () => {
        onClose()
        nav(`/?host=${encodeURIComponent(d.host_id)}`)
      },
    }))
    const seen = new Set<string>()
    const conts: Item[] = []
    for (const p of payloads) {
      for (const c of p.containers) {
        const key = `${p.host_id}:${c.name}`
        if (seen.has(key)) continue
        seen.add(key)
        conts.push({
          id: `c-${key}`,
          group: t('cmdkContainers'),
          label: c.name,
          sub: p.host_name,
          icon: <Box size={16} />,
          run: () => {
            onClose()
            nav(`/?host=${encodeURIComponent(p.host_id)}`)
          },
        })
      }
    }
    return [...screens, ...devs, ...conts]
  }, [devices, payloads, admin, nav, onClose, t])

  const filtered = useMemo(() => {
    const needle = q.trim().toLowerCase()
    if (!needle) return items
    const scored = items
      .map((it) => {
        const hay = `${it.label} ${it.sub ?? ''}`.toLowerCase()
        const idx = hay.indexOf(needle)
        return { it, rank: idx < 0 ? 999 : it.label.toLowerCase().startsWith(needle) ? 0 : 1 + idx / 100 }
      })
      .filter((x) => x.rank < 999)
      .sort((a, b) => a.rank - b.rank)
    return scored.map((x) => x.it)
  }, [items, q])

  useEffect(() => {
    if (active >= filtered.length) setActive(0)
  }, [filtered.length, active])

  // keep the active row in view
  useEffect(() => {
    listRef.current?.querySelector('[data-active="true"]')?.scrollIntoView({ block: 'nearest' })
  }, [active])

  if (!open) return null

  const onKey = (e: React.KeyboardEvent) => {
    if (e.key === 'ArrowDown') {
      e.preventDefault()
      setActive((i) => (i + 1) % Math.max(filtered.length, 1))
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      setActive((i) => (i - 1 + filtered.length) % Math.max(filtered.length, 1))
    } else if (e.key === 'Enter') {
      e.preventDefault()
      filtered[active]?.run()
    } else if (e.key === 'Escape') {
      e.preventDefault()
      onClose()
    }
  }

  let lastGroup = ''
  return createPortal(
    <div className="fixed inset-0 z-50 flex items-start justify-center p-4 pt-[12vh]">
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={onClose} />
      <div
        role="dialog"
        aria-modal="true"
        className="card animate-fade-in relative z-10 flex max-h-[70vh] w-full max-w-xl flex-col overflow-hidden p-0"
        onKeyDown={onKey}
      >
        <div className="flex items-center gap-2.5 border-b border-line/60 px-4 py-3">
          <Search size={17} className="text-text-secondary" />
          <input
            ref={inputRef}
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder={t('cmdkPlaceholder')}
            className="w-full bg-transparent text-sm text-text-primary outline-none placeholder:text-text-secondary"
          />
          <span className="panel-label hidden shrink-0 rounded border border-line/70 px-1.5 py-0.5 sm:inline">
            ESC
          </span>
        </div>

        <div ref={listRef} className="overflow-y-auto py-1.5">
          {filtered.length === 0 ? (
            <div className="px-4 py-8 text-center text-sm text-text-secondary">{t('cmdkEmpty')}</div>
          ) : (
            filtered.map((it, i) => {
              const header = it.group !== lastGroup ? it.group : null
              lastGroup = it.group
              const isActive = i === active
              return (
                <div key={it.id}>
                  {header && <div className="panel-label px-4 pb-1 pt-2">{header}</div>}
                  <button
                    data-active={isActive}
                    onMouseMove={() => setActive(i)}
                    onClick={() => it.run()}
                    className={`flex w-full items-center gap-3 px-4 py-2 text-start text-sm transition ${
                      isActive ? 'bg-primary/12 text-primary' : 'text-text-primary hover:bg-elevated'
                    }`}
                  >
                    <span className={isActive ? 'text-primary' : 'text-text-secondary'}>{it.icon}</span>
                    <span className="flex-1 truncate">{it.label}</span>
                    {it.sub && <span className="telemetry truncate text-xs text-text-secondary">{it.sub}</span>}
                    {isActive && <CornerDownLeft size={14} className="shrink-0 text-primary" />}
                  </button>
                </div>
              )
            })
          )}
        </div>
      </div>
    </div>,
    document.body,
  )
}
