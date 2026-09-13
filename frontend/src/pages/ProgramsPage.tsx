import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { api } from '../api/client'
import { ErrorNotice } from '../components/ErrorNotice'
import { StatusBadge } from '../components/StatusBadge'
import type { ApiPage, PublicProgram } from '../types/api'
import { formatDateTime } from '../utils/presentation'

export function formatDate(value: string) {
  return formatDateTime(value)
}

export function ProgramsPage() {
  const [result, setResult] = useState<ApiPage<PublicProgram>>()
  const [error, setError] = useState<unknown>()

  useEffect(() => { api.programs().then(setResult).catch(setError) }, [])

  return <section className="page">
    <div className="page-heading"><div><div className="eyebrow">게시된 지원사업</div><h1>지원사업</h1><p>현재 신청할 수 있는 지원사업과 접수 기간을 확인하세요.</p></div></div>
    {!result && error === undefined && <div className="notice" role="status">지원사업을 불러오는 중…</div>}
    {error !== undefined && <ErrorNotice error={error} />}
    {result?.items.length === 0 && <div className="empty"><h2>게시된 지원사업이 없습니다</h2><p>현재 안내할 사업이 없습니다. 잠시 후 다시 확인해 주세요.</p></div>}
    {result && result.items.length > 0 && <div className="program-grid">
      {result.items.map((program) => <article className="program-card" key={program.id}>
        <div className="card-top"><span className="program-code">{program.code}</span><StatusBadge status={program.intakeStatus} /></div>
        <h2><Link to={`/programs/${program.id}`}>{program.title}</Link></h2>
        <p className="description">{program.description}</p>
        <dl className="dates"><div><dt>접수 시작</dt><dd>{formatDate(program.applicationOpenAt)}</dd></div><div><dt>접수 마감</dt><dd>{formatDate(program.applicationCloseAt)}</dd></div></dl>
        <Link className="text-link" to={`/programs/${program.id}`}>사업 상세 보기 <span aria-hidden="true">→</span></Link>
      </article>)}
    </div>}
    {result && result.totalPages > 1 && <p className="pagination-summary">전체 {result.totalElements}개 중 {result.page + 1}/{result.totalPages}쪽</p>}
  </section>
}
