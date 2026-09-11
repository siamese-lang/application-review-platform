import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'

export function AdminRoute() {
  const { user, loading } = useAuth()
  const location = useLocation()
  if (loading) return <section className="page"><div className="notice" role="status">Checking your session…</div></section>
  if (!user) return <Navigate to="/login" replace state={{ from: location.pathname + location.search }} />
  if (user.role !== 'ADMIN') return <section className="page"><div className="notice error" role="alert"><strong>Administrator access required.</strong><span>This page is available only to administrator accounts.</span></div></section>
  return <Outlet />
}
