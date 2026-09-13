import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { api } from '../api/client'
import { ErrorNotice } from '../components/ErrorNotice'
import { StatusBadge } from '../components/StatusBadge'
import type { PublicProgram } from '../types/api'
import { formatDate } from './ProgramsPage'
import { useAuth } from '../auth/AuthContext'

export function ProgramDetailPage() {
  const { programId } = useParams()
  const [program, setProgram] = useState<PublicProgram>()
  const [error, setError] = useState<unknown>()
  const { user } = useAuth()
  useEffect(() => { if (programId) api.program(programId).then(setProgram).catch(setError) }, [programId])

  return <section className="page detail-page">
    <Link className="back-link" to="/programs">← 지원사업 목록</Link>
    {!program && error === undefined && <div className="notice" role="status">지원사업 상세 정보를 불러오는 중…</div>}
    {error !== undefined && <ErrorNotice error={error} />}
    {program && <article>
      <div className="detail-header"><div><span className="program-code">{program.code}</span><h1>{program.title}</h1></div><StatusBadge status={program.intakeStatus} /></div>
      <div className="detail-layout"><div className="detail-copy"><h2>사업 안내</h2><p>{program.description}</p></div><aside><h2>접수 기간</h2><dl className="dates stacked"><div><dt>접수 시작</dt><dd>{formatDate(program.applicationOpenAt)}</dd></div><div><dt>접수 마감</dt><dd>{formatDate(program.applicationCloseAt)}</dd></div></dl>{program.intakeStatus==='OPEN'&&user?.role==='APPLICANT'?<Link className="button full" to={`/applications/new?programId=${program.id}`}>신청서 작성</Link>:program.intakeStatus==='OPEN'&&!user?<p className="aside-note"><Link to="/login" state={{from:`/applications/new?programId=${program.id}`}}>로그인</Link>하거나 <Link to="/register">회원가입</Link>한 후 신청서를 작성하세요.</p>:<p className="aside-note">현재는 신규 신청을 접수하지 않습니다.</p>}</aside></div>
    </article>}
  </section>
}
