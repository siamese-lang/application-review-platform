import { type FormEvent, useState } from 'react'
import { Link } from 'react-router-dom'
import { api } from '../api/client'
import { ErrorNotice } from '../components/ErrorNotice'

export function RegisterPage() {
  const [error, setError] = useState<unknown>()
  const [submitting, setSubmitting] = useState(false)
  const [registered, setRegistered] = useState(false)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError(undefined)
    setSubmitting(true)
    const data = new FormData(event.currentTarget)
    try {
      await api.register({
        username: String(data.get('username')),
        password: String(data.get('password')),
        displayName: String(data.get('displayName')),
        email: String(data.get('email')),
      })
      setRegistered(true)
    } catch (requestError) {
      setError(requestError)
    } finally {
      setSubmitting(false)
    }
  }

  if (registered) return <section className="page auth-page"><div className="auth-card success-panel"><div className="success-icon">✓</div><h1>Registration complete</h1><p>Your applicant account is ready. Sign in separately to start a secure session.</p><Link className="button" to="/login">Continue to login</Link></div></section>

  return <section className="page auth-page"><div className="auth-intro"><div className="eyebrow">Applicant access</div><h1>Create your account</h1><p>Register to prepare and track applications. All new public accounts are applicant accounts.</p></div><form className="auth-card" onSubmit={submit}><h2>Account details</h2>{error !== undefined && <ErrorNotice error={error} />}<label>Username<input name="username" required maxLength={50} autoComplete="username" /></label><label>Display name<input name="displayName" required maxLength={120} autoComplete="name" /></label><label>Email address<input name="email" type="email" required maxLength={255} autoComplete="email" /></label><label>Password<input name="password" type="password" required minLength={12} maxLength={72} autoComplete="new-password" /><small>Use at least 12 characters.</small></label><button className="button full" disabled={submitting}>{submitting ? 'Creating account…' : 'Create applicant account'}</button><p className="form-footer">Already registered? <Link to="/login">Log in</Link></p></form></section>
}
