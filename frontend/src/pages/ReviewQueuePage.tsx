import { useEffect, useState } from 'react'
import { Link, useLocation } from 'react-router-dom'
import { api } from '../api/client'
import { ErrorNotice } from '../components/ErrorNotice'
import { StatusBadge } from '../components/StatusBadge'
import type { ApiPage, ReviewerQueueItem } from '../types/api'
import { formatMoney, formatTimestamp } from './ApplicationsPage'

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
  return <section className="page"><div className="page-heading"><div className="eyebrow">Reviewer workspace</div><h1>Review queue</h1><p>Oldest active review work is shown first. Starting a review assigns that application to you.</p></div>
    {message && <div className="notice success" role="status">{message}</div>}
    <div className="filters"><label>Status <select aria-label="Status" value={status} onChange={(event) => { setStatus(event.target.value as ReviewStatus); setPage(0) }}><option value="">All active review work</option><option value="SUBMITTED">Submitted</option><option value="IN_REVIEW">In review</option></select></label></div>
    {loading && <div className="notice" role="status">Loading review queue…</div>}{error !== undefined && <ErrorNotice error={error}/>} {!loading && !error && data?.items.length === 0 && <div className="empty"><h2>No active review work</h2><p>Applications matching this filter will appear here.</p></div>}
    {!loading && data && data.items.length > 0 && <div className="table-wrap"><table><thead><tr><th>Program</th><th>Applicant organization</th><th>Project</th><th>Requested amount</th><th>Status</th><th>Last updated</th><th></th></tr></thead><tbody>{data.items.map((item) => <tr key={item.id}><td><strong>{item.program.title}</strong><small>{item.program.code}</small></td><td>{item.applicantOrganizationName}</td><td>{item.projectTitle}</td><td>{formatMoney(item.requestedAmount)}</td><td><StatusBadge status={item.status}/></td><td>{formatTimestamp(item.updatedAt)}</td><td><Link className="text-link" to={`/review/applications/${item.id}`}>Review</Link></td></tr>)}</tbody></table></div>}
    {data && data.totalPages > 1 && <div className="pagination"><button className="button secondary compact" disabled={page === 0 || loading} onClick={() => setPage((value) => value - 1)}>Previous</button><span>Page {data.page + 1} of {data.totalPages}</span><button className="button secondary compact" disabled={page + 1 >= data.totalPages || loading} onClick={() => setPage((value) => value + 1)}>Next</button></div>}
  </section>
}
