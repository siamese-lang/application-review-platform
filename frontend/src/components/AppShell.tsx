import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import { useState } from 'react'
import { useAuth } from '../auth/AuthContext'
import { ErrorNotice } from './ErrorNotice'

export function AppShell() {
  const { user, loading, logout } = useAuth()
  const navigate = useNavigate()
  const [logoutError, setLogoutError] = useState<unknown>()

  async function handleLogout() {
    setLogoutError(undefined)
    try {
      await logout()
      navigate('/')
    } catch (error) {
      setLogoutError(error)
    }
  }

  return (
    <div className="site-frame">
      <header className="site-header">
        <NavLink to="/" className="brand" aria-label="지원사업 신청·심사 플랫폼 홈">
          <span className="brand-mark">지원</span>
          <span><strong>지원사업 신청·심사 플랫폼</strong><small>지원사업 통합 업무 서비스</small></span>
        </NavLink>
        <nav aria-label="주요 메뉴">
          <NavLink to="/programs">지원사업</NavLink>
          {!loading && user?.role === 'APPLICANT' && <NavLink to="/applications">내 신청</NavLink>}
          {!loading && user?.role === 'REVIEWER' && <NavLink to="/review">심사 업무</NavLink>}
          {!loading && user?.role === 'ADMIN' && <NavLink to="/admin">관리자</NavLink>}
          {!loading && !user && <NavLink to="/register">회원가입</NavLink>}
          {!loading && !user && <NavLink to="/login">로그인</NavLink>}
          {!loading && user && (
            <div className="session-actions">
              <span className="current-user"><small>로그인 사용자</small>{user.displayName}</span>
              <button className="button secondary compact" type="button" onClick={handleLogout}>로그아웃</button>
            </div>
          )}
        </nav>
      </header>
      {logoutError !== undefined && <div className="shell-alert"><ErrorNotice error={logoutError} /></div>}
      <main><Outlet /></main>
      <footer><span>지원사업 신청·심사 플랫폼</span><span>안전한 세션 기반 서비스</span></footer>
    </div>
  )
}
