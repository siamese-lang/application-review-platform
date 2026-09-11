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
        <NavLink to="/" className="brand" aria-label="Application Review Platform home">
          <span className="brand-mark">AR</span>
          <span><strong>Application Review</strong><small>Support program portal</small></span>
        </NavLink>
        <nav aria-label="Primary navigation">
          <NavLink to="/programs">Programs</NavLink>
          {!loading && !user && <NavLink to="/register">Register</NavLink>}
          {!loading && !user && <NavLink to="/login">Login</NavLink>}
          {!loading && user && (
            <div className="session-actions">
              <span className="current-user"><small>Signed in as</small>{user.displayName}</span>
              <button className="button secondary compact" type="button" onClick={handleLogout}>Log out</button>
            </div>
          )}
        </nav>
      </header>
      {logoutError && <div className="shell-alert"><ErrorNotice error={logoutError} /></div>}
      <main><Outlet /></main>
      <footer><span>Application Review Platform</span><span>Secure session-based service</span></footer>
    </div>
  )
}
