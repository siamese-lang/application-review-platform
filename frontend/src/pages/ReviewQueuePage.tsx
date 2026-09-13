import { useEffect, useState } from 'react'
import { Link, useLocation } from 'react-router-dom'
import { api } from '../api/client'
import { ErrorNotice } from '../components/ErrorNotice'
import { StatusBadge } from '../components/StatusBadge'
import type { ApiPage, ReviewerQueueItem } from '../types/api'
import { formatMoney, formatTimestamp } from './ApplicationsPage'
import { applicationStatusLabels } from '../utils/presentation'

type ReviewStatus = '' | 'SUBMITTED' | 'IN_REVIEW'

export function ReviewQueuePage() {
  const [page, setPage] = useState(0)
  const [status, setStatus] = useState<ReviewStatus>('')
  const [data, setData] = useState<ApiPage<ReviewerQueueItem>>()
  const [error, setError] = useState<unknown>()
  const [loading, setLoading] = useState(true)
  const location = useLocation()
  const message = (location.state as { message?: string } | null)?.message
  useEffect(() => {
    let active = true
    setLoading(true); setError(undefined)
    api.reviewQueue(page, 20, status || undefined).then((result) => { if (active) setData(result) }).catch((reason) => { if (active) setError(reason) }).finally(() => { if (active) setLoading(false) })
    return () => { active = false }
  }, [page, status])
  return <section className="page"><div className="page-heading"><div className="eyebrow">심사자 업무</div><h1>심사 업무</h1><p>접수된 순서대로 심사할 신청서를 확인하세요. 심사를 시작하면 해당 신청서의 담당 심사자로 배정됩니다.</p></div>
    {message && <div className="notice success" role="status">{message}</div>}
    <div className="filters"><label>진행 상태 <select aria-label="진행 상태" value={status} onChange={(event) => { setStatus(event.target.value as ReviewStatus); setPage(0) }}><option value="">전체 심사 업무</option><option value="SUBMITTED">제출 완료</option><option value="IN_REVIEW">심사 중</option></select></label></div>
    {loading && <div className="notice" role="status">심사 목록을 불러오는 중…</div>}{error !== undefined && <ErrorNotice error={error}/>} {!loading && !error && data?.items.length === 0 && <div className="empty"><h2>진행할 심사 업무가 없습니다</h2><p>선택한 조건에 해당하는 신청서가 없습니다.</p></div>}
    {!loading && data && data.items.length > 0 && <div className="table-wrap"><table><thead><tr><th>지원사업</th><th>신청 기관</th><th>과제명</th><th>신청 금액</th><th>진행 상태</th><th>최근 수정</th><th></th></tr></thead><tbody>{data.items.map((item) => <tr key={item.id}><td><strong>{item.program.title}</strong><small>{item.program.code}</small></td><td>{item.applicantOrganizationName}</td><td>{item.projectTitle}</td><td>{formatMoney(item.requestedAmount)}</td><td><StatusBadge status={item.status}/></td><td>{formatTimestamp(item.updatedAt)}</td><td><Link className="text-link" to={`/review/applications/${item.id}`}>심사하기</Link></td></tr>)}</tbody></table></div>}
    {data && data.totalPages > 1 && <div className="pagination"><button className="button secondary compact" disabled={page === 0 || loading} onClick={() => setPage((value) => value - 1)}>이전</button><span>{data.page + 1} / {data.totalPages}쪽</span><button className="button secondary compact" disabled={page + 1 >= data.totalPages || loading} onClick={() => setPage((value) => value + 1)}>다음</button></div>}
  </section>
}
