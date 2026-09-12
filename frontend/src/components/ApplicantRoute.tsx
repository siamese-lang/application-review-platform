import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'

export function ApplicantRoute() {
  const { user, loading } = useAuth()
  const location = useLocation()
  if (loading) return <section className="page"><div className="notice" role="status">로그인 상태를 확인하는 중…</div></section>
  if (!user) return <Navigate to="/login" replace state={{ from: location.pathname + location.search }} />
  if (user.role !== 'APPLICANT') return <section className="page"><div className="notice error" role="alert"><strong>신청자 권한이 필요합니다.</strong><span>이 페이지는 신청자 계정만 이용할 수 있습니다.</span></div></section>
  return <Outlet />
}
