import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { api } from '../api/client'
import { ErrorNotice } from '../components/ErrorNotice'
import { StatusBadge } from '../components/StatusBadge'
import type { ApiPage, ApplicationListItem, ApplicationStatus } from '../types/api'

const statuses: ApplicationStatus[] = ['DRAFT','SUBMITTED','IN_REVIEW','NEEDS_REVISION','APPROVED','REJECTED']
export function ApplicationsPage() {
  const [page, setPage] = useState(0); const [status, setStatus] = useState<ApplicationStatus | ''>(''); const [data, setData] = useState<ApiPage<ApplicationListItem>>(); const [error, setError] = useState<unknown>(); const [loading, setLoading] = useState(true)
  useEffect(() => { let active=true; setLoading(true); setError(undefined); api.applications(page, 20, status || undefined).then((x)=>{if(active)setData(x)}).catch((x)=>{if(active)setError(x)}).finally(()=>{if(active)setLoading(false)}); return()=>{active=false} }, [page,status])
  return <section className="page"><div className="page-heading heading-actions"><div><div className="eyebrow">Applicant workspace</div><h1>My applications</h1><p>Track drafts, review requests, and final decisions.</p></div><Link className="button" to="/programs">Find a program</Link></div>
    <div className="filters"><label>Status <select value={status} onChange={(e)=>{setStatus(e.target.value as ApplicationStatus|'');setPage(0)}}><option value="">All statuses</option>{statuses.map((x)=><option key={x}>{x}</option>)}</select></label></div>
    {loading && <div className="notice" role="status">Loading applications…</div>}{error !== undefined && <ErrorNotice error={error} />}
    {!loading && !error && data?.items.length === 0 && <div className="empty"><h2>No applications found</h2><p>Your applications matching this filter will appear here.</p></div>}
    {!loading && data && data.items.length > 0 && <div className="table-wrap"><table><thead><tr><th>Program</th><th>Project</th><th>Requested amount</th><th>Status</th><th>Last updated</th><th></th></tr></thead><tbody>{data.items.map((a)=><tr key={a.id}><td><strong>{a.program.title}</strong><small>{a.program.code}</small></td><td>{a.projectTitle}</td><td>{formatMoney(a.requestedAmount)}</td><td><StatusBadge status={a.status} /></td><td>{formatTimestamp(a.updatedAt)}</td><td><Link className="text-link" to={`/applications/${a.id}`}>View</Link></td></tr>)}</tbody></table></div>}
    {data && data.totalPages > 1 && <div className="pagination"><button className="button secondary compact" disabled={page===0||loading} onClick={()=>setPage((x)=>x-1)}>Previous</button><span>Page {data.page+1} of {data.totalPages}</span><button className="button secondary compact" disabled={page+1>=data.totalPages||loading} onClick={()=>setPage((x)=>x+1)}>Next</button></div>}
  </section>
}
export const formatMoney=(value:number)=>new Intl.NumberFormat(undefined,{style:'currency',currency:'KRW',maximumFractionDigits:2}).format(value)
export const formatTimestamp=(value:string)=>new Intl.DateTimeFormat(undefined,{dateStyle:'medium',timeStyle:'short'}).format(new Date(value))
