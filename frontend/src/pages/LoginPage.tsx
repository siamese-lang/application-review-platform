import { type FormEvent, useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'
import { ErrorNotice } from '../components/ErrorNotice'

export function LoginPage() {
  const { login } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const [error, setError] = useState<unknown>()
  const [submitting, setSubmitting] = useState(false)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError(undefined)
    setSubmitting(true)
    const data = new FormData(event.currentTarget)
    try {
      await login({ username: String(data.get('username')), password: String(data.get('password')) })
      navigate((location.state as { from?: string } | null)?.from ?? '/programs', { replace: true })
    } catch (requestError) {
      setError(requestError)
    } finally {
      setSubmitting(false)
    }
  }

  return <section className="page auth-page"><div className="auth-intro"><div className="eyebrow">Secure access</div><h1>Welcome back</h1><p>Sign in to your existing account. Your session is protected by the server and is not stored in browser JavaScript.</p></div><form className="auth-card" onSubmit={submit}><h2>Log in</h2>{error && <ErrorNotice error={error} />}<label>Username<input name="username" required maxLength={50} autoComplete="username" /></label><label>Password<input name="password" type="password" required maxLength={72} autoComplete="current-password" /></label><button className="button full" disabled={submitting}>{submitting ? 'Signing in…' : 'Log in'}</button><p className="form-footer">Need an applicant account? <Link to="/register">Register</Link></p></form></section>
}
