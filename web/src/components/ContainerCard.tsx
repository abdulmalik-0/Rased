import { useEffect, useRef, useState } from 'react'
import {
  ExternalLink,
  Link2,
  MoreVertical,
  Pencil,
  Sparkles,
  Terminal,
} from 'lucide-react'
import { useI18n } from '../lib/i18n'
import { useCopy } from '../lib/useCopy'
import { useToast } from '../lib/toast'
import type { ContainerMetrics } from '../lib/types'
import { AnalyzeDialog } from './dialogs/AnalyzeDialog'
import { LinkEditDialog } from './dialogs/LinkEditDialog'
import { LogsDialog } from './dialogs/LogsDialog'

interface Props {
  container: ContainerMetrics
  apiUrl: string
  hostId: string
  isAdmin: boolean
  customLink?: { url: string; label: string }
  onAction: (action: string) => void
  reloadLinks: () => void
}

const statusColor = (s: string) =>
  s === 'running'
    ? 'bg-accent shadow-[0_0_8px] shadow-accent/60'
    : s === 'paused'
      ? 'bg-warning'
      : s === 'exited' || s === 'dead'
        ? 'bg-danger'
        : 'bg-text-secondary'

const badgeTone = (s: string) =>
  s === 'running'
    ? 'bg-accent/12 text-accent'
    : s === 'paused'
      ? 'bg-warning/12 text-warning'
      : s === 'exited' || s === 'dead'
        ? 'bg-danger/12 text-danger'
        : 'bg-elevated text-text-secondary'

export function ContainerCard({
  container: c,
  apiUrl,
  hostId,
  isAdmin,
  customLink,
  onAction,
  reloadLinks,
}: Props) {
  const { t } = useI18n()
  const toast = useToast()
  const copy = useCopy()
  const [open, setOpen] = useState(false)
  const [analyze, setAnalyze] = useState(false)
  const [logs, setLogs] = useState(false)
  const [linkEdit, setLinkEdit] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)
  const running = c.status === 'running'
  const host = (() => {
    try {
      return new URL(apiUrl).hostname
    } catch {
      return ''
    }
  })()

  useEffect(() => {
    if (!open) return
    const h = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', h)
    return () => document.removeEventListener('mousedown', h)
  }, [open])

  const openUrl = (url: string) => {
    if (!window.open(url, '_blank')) toast(`${t('cannotOpen')}: ${url}`)
  }
  const act = (a: string) => {
    setOpen(false)
    onAction(a)
  }

  return (
    <div className="card card-hover flex flex-col p-4">
      <div className="flex items-center gap-2">
        <span className={`h-2.5 w-2.5 rounded-full ${statusColor(c.status)}`} />
        <span className="flex-1 truncate font-semibold text-text-primary" title={c.name}>
          {c.name}
        </span>
        <span
          className={`rounded-md px-2 py-0.5 text-[10px] font-bold uppercase ${badgeTone(c.status)}`}
        >
          {c.status}
        </span>
        <div className="relative" ref={menuRef}>
          <button
            onClick={() => setOpen((o) => !o)}
            className="rounded p-1 text-text-secondary hover:bg-elevated"
          >
            <MoreVertical size={18} />
          </button>
          {open && (
            <div className="absolute end-0 z-20 mt-1 w-40 overflow-hidden rounded-lg border border-line bg-surface py-1 shadow-cardHover">
              <MenuItem
                label={t('copyName')}
                onClick={() => {
                  copy(c.name)
                  setOpen(false)
                }}
              />
              <MenuItem
                icon={<Terminal size={15} />}
                label={t('viewLogs')}
                onClick={() => {
                  setLogs(true)
                  setOpen(false)
                }}
              />
              {isAdmin && <MenuItem label={t('restart')} onClick={() => act('restart')} />}
              {isAdmin &&
                (running ? (
                  <MenuItem label={t('stop')} onClick={() => act('stop')} />
                ) : (
                  <MenuItem label={t('start')} onClick={() => act('start')} />
                ))}
            </div>
          )}
        </div>
      </div>

      <div className="mt-1 truncate text-xs text-text-secondary">{c.image}</div>

      {(c.ports.length > 0 || customLink?.url || isAdmin) && (
        <div className="mt-2 flex flex-wrap gap-1.5">
          {customLink?.url && (
            <Chip
              icon={<Link2 size={13} />}
              label={customLink.label || customLink.url}
              tone="accent"
              onClick={() => openUrl(customLink.url)}
            />
          )}
          {c.ports.map((p) => (
            <Chip
              key={p}
              icon={<ExternalLink size={13} />}
              label={`:${p}`}
              tone="primary"
              onClick={() => host && openUrl(`http://${host}:${p}`)}
            />
          ))}
          {isAdmin && (
            <Chip icon={<Pencil size={13} />} label={t('editLink')} onClick={() => setLinkEdit(true)} />
          )}
        </div>
      )}

      {running && (
        <div className="mt-3 flex flex-wrap gap-2">
          <Stat label={t('cpu')} value={`${c.cpu_percent.toFixed(1)}%`} />
          <Stat
            label={t('ram')}
            value={`${c.memory_percent.toFixed(0)}% · ${c.memory_usage_mb.toFixed(0)}/${c.memory_limit_mb.toFixed(0)}MB`}
          />
          {c.restart_count > 0 && <Stat label={t('restarts')} value={`${c.restart_count}`} />}
        </div>
      )}

      <button
        onClick={() => setAnalyze(true)}
        className="mt-3 flex items-center justify-center gap-2 rounded-xl border border-primary/60 py-2 text-sm font-medium text-primary transition hover:bg-primary/10"
      >
        <Sparkles size={16} /> {t('analyzeLogs')}
      </button>

      {analyze && (
        <AnalyzeDialog
          open={analyze}
          onClose={() => setAnalyze(false)}
          container={c}
          apiUrl={apiUrl}
          hostId={hostId}
        />
      )}
      {logs && (
        <LogsDialog open={logs} onClose={() => setLogs(false)} container={c} apiUrl={apiUrl} />
      )}
      {linkEdit && (
        <LinkEditDialog
          open={linkEdit}
          onClose={() => setLinkEdit(false)}
          hostId={hostId}
          containerName={c.name}
          initial={customLink}
          onSaved={reloadLinks}
        />
      )}
    </div>
  )
}

function MenuItem(props: { icon?: React.ReactNode; label: string; onClick: () => void }) {
  return (
    <button
      onClick={props.onClick}
      className="flex w-full items-center gap-2 px-3 py-1.5 text-start text-sm text-text-primary hover:bg-elevated"
    >
      {props.icon}
      {props.label}
    </button>
  )
}

function Chip(props: {
  icon: React.ReactNode
  label: string
  tone?: 'primary' | 'accent'
  onClick: () => void
}) {
  const color =
    props.tone === 'accent'
      ? 'text-accent'
      : props.tone === 'primary'
        ? 'text-primary'
        : 'text-text-secondary'
  return (
    <button
      onClick={props.onClick}
      className={`inline-flex items-center gap-1 rounded-lg bg-elevated px-2 py-1 text-[11px] ${color} transition hover:opacity-80`}
    >
      {props.icon}
      <span className="max-w-[160px] truncate">{props.label}</span>
    </button>
  )
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <span className="rounded-lg bg-elevated px-2 py-1 text-xs text-text-primary">
      {label}: {value}
    </span>
  )
}
