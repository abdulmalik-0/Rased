import { NavLink } from 'react-router-dom'
import {
  Activity,
  HelpCircle,
  LayoutDashboard,
  LineChart,
  MessageSquare,
  Settings,
  Users,
  type LucideIcon,
} from 'lucide-react'
import { useAuth } from '../lib/auth'
import { useI18n } from '../lib/i18n'
import { isAdmin } from '../lib/types'

interface Item {
  to: string
  icon: LucideIcon
  key: string
  soon?: boolean
  admin?: boolean
}

const ITEMS: Item[] = [
  { to: '/', icon: LayoutDashboard, key: 'dashboard' },
  { to: '/history', icon: LineChart, key: 'history' },
  { to: '/chat', icon: MessageSquare, key: 'askAi' },
  { to: '/settings', icon: Settings, key: 'settings' },
  { to: '/users', icon: Users, key: 'users', admin: true },
  { to: '/help', icon: HelpCircle, key: 'help' },
]

export function Sidebar({ onNavigate }: { onNavigate?: () => void }) {
  const { t } = useI18n()
  const { session } = useAuth()
  const items = ITEMS.filter((i) => !i.admin || isAdmin(session))

  return (
    <div className="flex h-full w-60 flex-col border-e border-line/70 bg-surface/60 backdrop-blur-xl">
      <div className="flex items-center gap-2.5 px-5 py-5">
        <div className="grid h-9 w-9 place-items-center rounded-xl bg-gradient-to-br from-primary to-accent shadow-lg shadow-primary/20">
          <Activity className="text-white" size={20} />
        </div>
        <div>
          <div className="text-[15px] font-bold leading-tight text-text-primary">
            {t('appTitle')}
          </div>
          <div className="text-[11px] text-text-secondary">Server monitoring</div>
        </div>
      </div>

      <nav className="flex-1 space-y-1 px-3 py-2">
        {items.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.to === '/'}
            onClick={onNavigate}
            className={({ isActive }) =>
              `group flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition ${
                isActive
                  ? 'bg-primary/12 text-primary shadow-sm'
                  : 'text-text-secondary hover:bg-elevated hover:text-text-primary'
              }`
            }
          >
            <item.icon size={18} />
            <span className="flex-1">{t(item.key)}</span>
            {item.soon && (
              <span className="rounded-md bg-elevated px-1.5 py-0.5 text-[9px] font-semibold uppercase text-text-secondary">
                {t('soon')}
              </span>
            )}
          </NavLink>
        ))}
      </nav>

      <div className="border-t border-line/70 px-5 py-3 text-[11px] text-text-secondary">
        v1.0 · Rased
      </div>
    </div>
  )
}
