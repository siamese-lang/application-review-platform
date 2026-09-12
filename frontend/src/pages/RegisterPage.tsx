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

  if (registered) return <section className="page auth-page"><div className="auth-card success-panel"><div className="success-icon">✓</div><h1>회원가입 완료</h1><p>신청자 계정이 만들어졌습니다. 로그인하여 지원사업 신청을 시작하세요.</p><Link className="button" to="/login">로그인하기</Link></div></section>

  return <section className="page auth-page"><div className="auth-intro"><div className="eyebrow">신청자 회원가입</div><h1>신청자 계정 만들기</h1><p>지원사업 신청서를 작성하고 진행 상태를 확인할 수 있습니다. 일반 회원가입 계정은 신청자 권한으로 생성됩니다.</p></div><form className="auth-card" onSubmit={submit}><h2>계정 정보</h2>{error !== undefined && <ErrorNotice error={error} />}<label>아이디<input name="username" required maxLength={50} autoComplete="username" /></label><label>이름<input name="displayName" required maxLength={120} autoComplete="name" /></label><label>이메일 주소<input name="email" type="email" required maxLength={255} autoComplete="email" /></label><label>비밀번호<input name="password" type="password" required minLength={12} maxLength={72} autoComplete="new-password" /><small>12자 이상 입력해 주세요.</small></label><button className="button full" disabled={submitting}>{submitting ? '계정 생성 중…' : '신청자 계정 만들기'}</button><p className="form-footer">이미 가입하셨나요? <Link to="/login">로그인</Link></p></form></section>
}
