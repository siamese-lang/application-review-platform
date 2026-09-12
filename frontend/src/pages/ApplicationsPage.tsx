import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { api } from '../api/client'
import { ErrorNotice } from '../components/ErrorNotice'
import { StatusBadge } from '../components/StatusBadge'
import type { ApiPage, ApplicationListItem, ApplicationStatus } from '../types/api'
import { applicationStatusLabels, formatDateTime, formatMoney as formatWon } from '../utils/presentation'

const statuses: ApplicationStatus[] = ['DRAFT','SUBMITTED','IN_REVIEW','NEEDS_REVISION','APPROVED','REJECTED']
export function ApplicationsPage() {
  const [page, setPage] = useState(0); const [status, setStatus] = useState<ApplicationStatus | ''>(''); const [data, setData] = useState<ApiPage<ApplicationListItem>>(); const [error, setError] = useState<unknown>(); const [loading, setLoading] = useState(true)
  useEffect(() => { let active=true; setLoading(true); setError(undefined); api.applications(page, 20, status || undefined).then((x)=>{if(active)setData(x)}).catch((x)=>{if(active)setError(x)}).finally(()=>{if(active)setLoading(false)}); return()=>{active=false} }, [page,status])
  return <section className="page"><div className="page-heading heading-actions"><div><div className="eyebrow">신청자 업무</div><h1>내 신청</h1><p>작성 중인 신청서와 보완 요청, 최종 심사 결과를 확인하세요.</p></div><Link className="button" to="/programs">지원사업 찾기</Link></div>
    <div className="filters"><label>진행 상태 <select value={status} onChange={(e)=>{setStatus(e.target.value as ApplicationStatus|'');setPage(0)}}><option value="">전체 상태</option>{statuses.map((x)=><option key={x} value={x}>{applicationStatusLabels[x]}</option>)}</select></label></div>
    {loading && <div className="notice" role="status">신청 내역을 불러오는 중…</div>}{error !== undefined && <ErrorNotice error={error} />}
    {!loading && !error && data?.items.length === 0 && <div className="empty"><h2>신청 내역이 없습니다</h2><p>선택한 조건에 해당하는 신청서가 없습니다.</p></div>}
    {!loading && data && data.items.length > 0 && <div className="table-wrap"><table><thead><tr><th>지원사업</th><th>과제명</th><th>신청 금액</th><th>진행 상태</th><th>최근 수정</th><th></th></tr></thead><tbody>{data.items.map((a)=><tr key={a.id}><td><strong>{a.program.title}</strong><small>{a.program.code}</small></td><td>{a.projectTitle}</td><td>{formatMoney(a.requestedAmount)}</td><td><StatusBadge status={a.status} /></td><td>{formatTimestamp(a.updatedAt)}</td><td><Link className="text-link" to={`/applications/${a.id}`}>상세 보기</Link></td></tr>)}</tbody></table></div>}
    {data && data.totalPages > 1 && <div className="pagination"><button className="button secondary compact" disabled={page===0||loading} onClick={()=>setPage((x)=>x-1)}>이전</button><span>{data.page+1} / {data.totalPages}쪽</span><button className="button secondary compact" disabled={page+1>=data.totalPages||loading} onClick={()=>setPage((x)=>x+1)}>다음</button></div>}
  </section>
}
export const formatMoney = formatWon
export const formatTimestamp = formatDateTime
