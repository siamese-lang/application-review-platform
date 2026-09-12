import { type FormEvent, useCallback, useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { api, ApiError } from '../api/client'
import { ErrorNotice } from '../components/ErrorNotice'
import { StatusBadge } from '../components/StatusBadge'
import type { ApplicationDetail, ApplicationHistory, Attachment } from '../types/api'
import { formatMoney, formatTimestamp } from './ApplicationsPage'
import { applicationStatusLabel } from '../utils/presentation'

const editable = (status: ApplicationDetail['status']) => status === 'DRAFT' || status === 'NEEDS_REVISION'
const messages: Record<ApplicationDetail['status'], string> = {
  DRAFT: '신청 내용과 첨부 파일을 확인한 뒤 최종 제출하세요.', NEEDS_REVISION: '아래 보완 사유를 확인하고 신청 내용을 수정한 뒤 다시 제출하세요.',
  SUBMITTED: '신청서가 제출되어 심사자 배정을 기다리고 있습니다.', IN_REVIEW: '담당 심사자가 신청 내용을 검토하고 있습니다.', APPROVED: '신청이 승인되었습니다.', REJECTED: '신청이 반려되었습니다. 처리 사유를 확인하세요.',
}
export function ApplicationDetailPage() {
  const { applicationId }=useParams(); const [application,setApplication]=useState<ApplicationDetail>(); const [history,setHistory]=useState<ApplicationHistory[]>([]); const [attachments,setAttachments]=useState<Attachment[]>([])
  const [error,setError]=useState<unknown>(); const [attachmentError,setAttachmentError]=useState<unknown>(); const [submitting,setSubmitting]=useState(false); const [uploading,setUploading]=useState(false); const [conflict,setConflict]=useState(false)
  const load=useCallback(async()=>{if(!applicationId)return; setError(undefined); try { const [a,h,f]=await Promise.all([api.application(applicationId),api.applicationHistory(applicationId),api.attachments(applicationId)]);setApplication(a);setHistory(h);setAttachments(f) }catch(e){setError(e)}},[applicationId])
  useEffect(()=>{void load()},[load])
  async function submit(){if(!applicationId||!application)return;setSubmitting(true);setError(undefined);setConflict(false);try{setApplication(await api.submitApplication(applicationId,application.version));await load()}catch(e){setError(e);setConflict(e instanceof ApiError&&e.status===409)}finally{setSubmitting(false)}}
  async function upload(event:FormEvent<HTMLFormElement>){event.preventDefault();if(!applicationId)return;const form=event.currentTarget;const file=(new FormData(form).get('file'));if(!(file instanceof File)||file.size===0)return;setUploading(true);setAttachmentError(undefined);try{await api.uploadAttachment(applicationId,file);setAttachments(await api.attachments(applicationId));form.reset()}catch(e){setAttachmentError(e)}finally{setUploading(false)}}
  async function remove(id:number){if(!applicationId)return;setAttachmentError(undefined);try{await api.deleteAttachment(applicationId,id);setAttachments(await api.attachments(applicationId))}catch(e){setAttachmentError(e)}}
  async function download(file:Attachment){if(!applicationId)return;setAttachmentError(undefined);try{const result=await api.downloadAttachment(applicationId,file.id);const url=URL.createObjectURL(result.blob);const link=document.createElement('a');link.href=url;link.download=result.filename||file.filename;link.click();URL.revokeObjectURL(url)}catch(e){setAttachmentError(e)}}
  return <section className="page detail-page application-detail"><Link className="back-link" to="/applications">← 내 신청</Link>
    {!application&&error===undefined&&<div className="notice" role="status">신청서를 불러오는 중…</div>}{error!==undefined&&<ErrorNotice error={error}/>} {conflict&&<div className="conflict-actions"><strong>처리 중 신청서가 변경되었습니다.</strong><span>자동으로 다시 제출하지 않았습니다. 최신 내용을 확인해 주세요.</span><button className="button secondary" onClick={load}>최신 신청서 불러오기</button></div>}
    {application&&<><header className="detail-header"><div><span className="program-code">{application.program.code} · {application.program.title}</span><h1>{application.projectTitle}</h1></div><StatusBadge status={application.status}/></header>
      <div className="workflow-panel"><p>{messages[application.status]}</p>{editable(application.status)&&<div className="action-row"><Link className="button secondary" to={`/applications/${application.id}/edit`}>수정</Link><button className="button" disabled={submitting} onClick={submit}>{submitting?'제출 중…':application.status==='DRAFT'?'최종 제출':'다시 제출'}</button></div>}</div>
      <section className="content-panel"><h2>신청 정보</h2><dl className="information-grid"><div><dt>신청 기관</dt><dd>{application.applicantOrganizationName}</dd></div><div><dt>신청 금액</dt><dd>{formatMoney(application.requestedAmount)}</dd></div><div className="wide"><dt>요약</dt><dd>{application.shortSummary}</dd></div><div className="wide"><dt>세부 계획</dt><dd>{application.detailedPlan}</dd></div><div><dt>작성일</dt><dd>{formatTimestamp(application.createdAt)}</dd></div><div><dt>수정일</dt><dd>{formatTimestamp(application.updatedAt)}</dd></div></dl></section>
      <section className="content-panel"><h2>첨부 파일</h2>{attachmentError!==undefined&&<ErrorNotice error={attachmentError}/>} {editable(application.status)&&<form className="upload-form" onSubmit={upload}><label>증빙 파일<input name="file" type="file" required disabled={uploading}/></label><button className="button secondary" disabled={uploading}>{uploading?'업로드 중…':'파일 올리기'}</button></form>}
        {attachments.length===0?<p className="muted">첨부 파일이 없습니다.</p>:<div className="attachment-list">{attachments.map((f)=><div key={f.id}><div><strong>{f.filename}</strong><small>{f.contentType} · {f.size===null?'크기 확인 중':formatBytes(f.size)} · {f.status} · {formatTimestamp(f.createdAt)}</small></div><div className="action-row">{f.status==='AVAILABLE'&&<button className="text-button" onClick={()=>download(f)}>다운로드</button>}{editable(application.status)&&<button className="text-button danger" onClick={()=>remove(f.id)}>삭제</button>}</div></div>)}</div>}</section>
      <section className="content-panel"><h2>진행 이력</h2>{history.length===0?<p className="muted">기록된 진행 이력이 없습니다.</p>:<ol className="timeline">{history.map((h)=><li key={h.id}><time>{formatTimestamp(h.changedAt)}</time><strong>{h.fromStatus ? `${applicationStatusLabel(h.fromStatus)} → ` : ''}{applicationStatusLabel(h.toStatus)}</strong>{h.reason&&<p>{h.reason}</p>}</li>)}</ol>}</section></>}
  </section>
}
const formatBytes=(size:number)=>size<1024?`${size} B`:size<1048576?`${(size/1024).toFixed(1)} KB`:`${(size/1048576).toFixed(1)} MB`
