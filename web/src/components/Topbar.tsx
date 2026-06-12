import {
  Activity,
  Languages,
  LogOut,
  Moon,
  RefreshCw,
  Sun,
  type LucideIcon,
} from 'lucide-react'
import { useAuth } from '../lib/auth'
import { useI18n } from '../lib/i18n'
import { useTheme } from '../lib/theme'

export function Topbar({ online, onRefresh }: { online: boolean; onRefresh: () => void }) {
  const { t, toggle: toggleLang } = useI18n()
  const { theme, toggle: toggleTheme } = useTheme()
  const { logout } = useAuth()
  return (
    <header className="flex items-center gap-2 border-b border-line bg-surface px-4 py-2">
      <Activity className="text-primary" size={22} />
      <span className="font-bold text-text-primary">{t('appTitle')}</span>
      <span
        className={`ms-2 rounded px-2 py-0.5 text-[11px] ${
          online ? 'bg-accent/15 text-accent' : 'bg-danger/15 text-danger'
        }`}
      >
        {online ? t('agentOnline') : t('agentOffline')}
      </span>
      <div className="ms-auto flex items-center gap-1">
        <IconBtn title={t('refresh')} icon={RefreshCw} onClick={onRefresh} />
        <IconBtn title={t('language')} icon={Languages} onClick={toggleLang} />
        <IconBtn
          title={t('theme')}
          icon={theme === 'dark' ? Sun : Moon}
          onClick={toggleTheme}
        />
        <IconBtn title={t('signOut')} icon={LogOut} onClick={logout} />
      </div>
    </header>
  )
}

function IconBtn({
  icon: Icon,
  title,
  onClick,
}: {
  icon: LucideIcon
  title: string
  onClick: () => void
}) {
  return (
    <button
      title={title}
      onClick={onClick}
      className="rounded-lg p-2 text-text-secondary transition hover:bg-elevated hover:text-text-primary"
    >
      <Icon size={18} />
    </button>
  )
}
