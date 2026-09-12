import { type FormEvent, useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'
import { ErrorNotice } from '../components/ErrorNotice'
import type { Role } from '../types/api'

const roleHome: Record<Role, string> = {
  APPLICANT: '/programs',
  REVIEWER: '/review',
  ADMIN: '/admin',
}

function canReturnTo(role: Role, path: string) {
  if (role === 'APPLICANT') return path === '/applications' || path.startsWith('/applications/')
  if (role === 'REVIEWER') return path === '/review' || path.startsWith('/review/')
  return path === '/admin' || path.startsWith('/admin/')
}

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
      const current = await login({ username: String(data.get('username')), password: String(data.get('password')) })
      const from = (location.state as { from?: string } | null)?.from
      navigate(from && canReturnTo(current.role, from) ? from : roleHome[current.role], { replace: true })
    } catch (requestError) {
      setError(requestError)
    } finally {
      setSubmitting(false)
    }
  }

  return <section className="page auth-page"><div className="auth-intro"><div className="eyebrow">안전한 로그인</div><h1>로그인</h1><p>계정으로 로그인해 담당 업무를 계속하세요. 로그인 정보는 서버의 안전한 세션으로 보호됩니다.</p></div><form className="auth-card" onSubmit={submit}><h2>로그인</h2>{error !== undefined && <ErrorNotice error={error} />}<label>아이디<input name="username" required maxLength={50} autoComplete="username" /></label><label>비밀번호<input name="password" type="password" required maxLength={72} autoComplete="current-password" /></label><button className="button full" disabled={submitting}>{submitting ? '로그인 중…' : '로그인'}</button><p className="form-footer">신청자 계정이 필요하신가요? <Link to="/register">회원가입</Link></p></form></section>
}
