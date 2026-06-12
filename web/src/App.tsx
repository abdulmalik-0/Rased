import { Navigate, Route, Routes } from 'react-router-dom'
import { AppShell } from './components/AppShell'
import { useAuth } from './lib/auth'
import Dashboard from './screens/Dashboard'
import Login from './screens/Login'
import Placeholder from './screens/Placeholder'
import Users from './screens/Users'

export default function App() {
  const { session } = useAuth()
  if (!session) return <Login />
  return (
    <AppShell>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/history" element={<Placeholder titleKey="history" />} />
        <Route path="/chat" element={<Placeholder titleKey="askAi" />} />
        <Route path="/settings" element={<Placeholder titleKey="settings" />} />
        <Route path="/users" element={<Users />} />
        <Route path="/help" element={<Placeholder titleKey="help" />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AppShell>
  )
}
