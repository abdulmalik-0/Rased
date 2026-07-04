import { useEffect, useState, type ReactNode } from 'react'
import { ChevronDown, LogOut, Menu, Moon, Search, Sun } from 'lucide-react'
import { useAuth } from '../lib/auth'
import { useI18n } from '../lib/i18n'
import { useTheme } from '../lib/theme'
import { CommandPalette } from './CommandPalette'
import { RadarMark } from './RadarMark'
import { Sidebar } from './Sidebar'

export function AppShell({ children }: { children: ReactNode }) {
  const [drawer, setDrawer] = useState(false)
  const [cmdk, setCmdk] = useState(false)

  // Global ⌘K / Ctrl+K to open the command palette.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault()
        setCmdk((o) => !o)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  return (
    <div className="flex h-full">
      <aside className="hidden shrink-0 md:block">
        <Sidebar />
      </aside>

      {drawer && (
        <div className="fixed inset-0 z-40 md:hidden">
          <div
            className="absolute inset-0 bg-black/60 backdrop-blur-sm"
            onClick={() => setDrawer(false)}
          />
          <div className="absolute inset-y-0 start-0 animate-fade-in">
            <Sidebar onNavigate={() => setDrawer(false)} />
          </div>
        </div>
      )}

      <div className="flex min-w-0 flex-1 flex-col">
        <TopBar onMenu={() => setDrawer(true)} onSearch={() => setCmdk(true)} />
        <main className="flex-1 overflow-y-auto">{children}</main>
      </div>

      <CommandPalette open={cmdk} onClose={() => setCmdk(false)} />
    </div>
  )
}

function TopBar({ onMenu, onSearch }: { onMenu: () => void; onSearch: () => void }) {
  const { t, toggle: toggleLang, lang } = useI18n()
  const { theme, toggle: toggleTheme } = useTheme()
  const { session, logout } = useAuth()
  const [menu, setMenu] = useState(false)

  return (
    <header className="sticky top-0 z-30 flex items-center gap-1.5 border-b border-line/70 bg-bg/70 px-3 py-2.5 backdrop-blur-xl sm:px-5">
      <button className="btn-ghost md:hidden" onClick={onMenu} aria-label="Menu">
        <Menu size={20} />
      </button>
      <div className="flex items-center gap-2 font-bold tracking-tight text-text-primary md:hidden">
        <RadarMark size={26} />
        {t('appTitle')}
      </div>

      <button
        onClick={onSearch}
        className="ms-auto flex items-center gap-2 rounded-lg border border-line/70 bg-surface px-2.5 py-1.5 text-text-secondary transition hover:border-primary/35 hover:text-text-primary sm:min-w-[220px]"
        title={t('cmdkPlaceholder')}
      >
        <Search size={15} />
        <span className="hidden flex-1 truncate text-start text-xs sm:block">
          {t('cmdkPlaceholder')}
        </span>
        <span className="panel-label hidden shrink-0 rounded border border-line/70 px-1.5 py-0.5 sm:inline">
          ⌘K
        </span>
      </button>

      <div className="flex items-center gap-1">
        <button
          className="btn-ghost min-w-9 font-mono text-xs font-bold"
          title={t('language')}
          onClick={toggleLang}
        >
          {lang === 'ar' ? 'EN' : 'ع'}
        </button>
        <button className="btn-ghost" title={t('theme')} onClick={toggleTheme}>
          {theme === 'dark' ? <Sun size={18} /> : <Moon size={18} />}
        </button>

        <div className="relative">
          <button
            onClick={() => setMenu((m) => !m)}
            className="flex items-center gap-2 rounded-xl border border-line/70 bg-surface px-2 py-1.5 transition hover:bg-elevated"
          >
            <span className="grid h-6 w-6 place-items-center rounded-lg bg-primary/15 text-[11px] font-bold text-primary">
              {(session?.email || '?')[0]?.toUpperCase()}
            </span>
            <span className="hidden max-w-[150px] truncate text-xs text-text-secondary sm:block">
              {session?.email}
            </span>
            <ChevronDown size={14} className="text-text-secondary" />
          </button>
          {menu && (
            <>
              <div className="fixed inset-0 z-10" onClick={() => setMenu(false)} />
              <div className="absolute end-0 z-20 mt-1.5 w-48 animate-fade-in overflow-hidden rounded-xl border border-line/70 bg-surface shadow-cardHover">
                <div className="truncate px-3 py-2.5 text-xs text-text-secondary">
                  {session?.email}
                </div>
                <div className="border-t border-line/70" />
                <button
                  onClick={logout}
                  className="flex w-full items-center gap-2 px-3 py-2.5 text-start text-sm text-danger hover:bg-elevated"
                >
                  <LogOut size={15} />
                  {t('signOut')}
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </header>
  )
}
