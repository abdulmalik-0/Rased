import { Navigate, Route, Routes } from 'react-router-dom'
import { AppShell } from './components/AppShell'
import { useAuth } from './lib/auth'
import { SettingsProvider } from './lib/settings'
import Alerts from './screens/Alerts'
import Chat from './screens/Chat'
import Dashboard from './screens/Dashboard'
import Help from './screens/Help'
import History from './screens/History'
import Login from './screens/Login'
import Radar from './screens/Radar'
import Settings from './screens/Settings'
import Users from './screens/Users'

export default function App() {
  const { session } = useAuth()
  if (!session) return <Login />
  return (
    <SettingsProvider>
      <AppShell>
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/radar" element={<Radar />} />
          <Route path="/history" element={<History />} />
          <Route path="/alerts" element={<Alerts />} />
          <Route path="/chat" element={<Chat />} />
          <Route path="/settings" element={<Settings />} />
          <Route path="/users" element={<Users />} />
          <Route path="/help" element={<Help />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </AppShell>
    </SettingsProvider>
  )
}
