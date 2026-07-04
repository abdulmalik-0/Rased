import { NavLink } from 'react-router-dom'
import {
  Bell,
  HelpCircle,
  LayoutDashboard,
  LineChart,
  MessageSquare,
  Radar,
  Settings,
  Users,
  type LucideIcon,
} from 'lucide-react'
import { useAuth } from '../lib/auth'
import { useI18n } from '../lib/i18n'
import { isAdmin } from '../lib/types'
import { RadarMark } from './RadarMark'

interface Item {
  to: string
  icon: LucideIcon
  key: string
  soon?: boolean
  admin?: boolean
}

const ITEMS: Item[] = [
  { to: '/', icon: LayoutDashboard, key: 'dashboard' },
  { to: '/radar', icon: Radar, key: 'radar' },
  { to: '/alerts', icon: Bell, key: 'alertsScreen' },
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
      <div className="flex items-center gap-3 px-5 py-5">
        <RadarMark size={40} />
        <div className="min-w-0">
          <div className="truncate text-[17px] font-bold leading-tight tracking-tight text-text-primary">
            {t('appTitle')}
          </div>
          <div className="panel-label truncate">{t('brandTagline')}</div>
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
              `group relative flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition ${
                isActive
                  ? 'bg-primary/10 text-primary'
                  : 'text-text-secondary hover:bg-elevated hover:text-text-primary'
              }`
            }
          >
            {({ isActive }) => (
              <>
                {isActive && (
                  <span className="absolute inset-y-1.5 start-0 w-0.5 rounded-full bg-primary shadow-glow" />
                )}
                <item.icon size={18} className={isActive ? 'glow-teal' : ''} />
                <span className="flex-1">{t(item.key)}</span>
                {item.soon && (
                  <span className="panel-label rounded bg-elevated px-1.5 py-0.5">
                    {t('soon')}
                  </span>
                )}
              </>
            )}
          </NavLink>
        ))}
      </nav>

      <div className="panel-label border-t border-line/70 px-5 py-3">
        v1.0 <span className="text-primary/70">//</span> RASED
      </div>
    </div>
  )
}
