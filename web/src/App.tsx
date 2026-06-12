import { Navigate, Route, Routes } from 'react-router-dom'
import { useAuth } from './lib/auth'
import Dashboard from './screens/Dashboard'
import Login from './screens/Login'

export default function App() {
  const { session } = useAuth()
  if (!session) return <Login />
  return (
    <Routes>
      <Route path="/" element={<Dashboard />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
