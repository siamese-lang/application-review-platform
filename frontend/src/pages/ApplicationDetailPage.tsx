import { type FormEvent, useCallback, useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { api, ApiError } from '../api/client'
import { ErrorNotice } from '../components/ErrorNotice'
import { StatusBadge } from '../components/StatusBadge'
import type { ApplicationDetail, ApplicationHistory, Attachment } from '../types/api'
import { formatMoney, formatTimestamp } from './ApplicationsPage'

const editable = (status: ApplicationDetail['status']) => status === 'DRAFT' || status === 'NEEDS_REVISION'
const messages: Record<ApplicationDetail['status'], string> = {
  DRAFT: 'Complete the application and supporting files before submission.', NEEDS_REVISION: 'Review the reason below, update the application, and resubmit.',
  SUBMITTED: 'Submitted and waiting for a reviewer.', IN_REVIEW: 'A reviewer is assessing this application.', APPROVED: 'This application has been approved.', REJECTED: 'This application has been rejected.',
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
  return <section className="page detail-page application-detail"><Link className="back-link" to="/applications">← My applications</Link>
    {!application&&error===undefined&&<div className="notice" role="status">Loading application…</div>}{error!==undefined&&<ErrorNotice error={error}/>} {conflict&&<div className="conflict-actions"><strong>This application changed before the action completed.</strong><span>It was not submitted again automatically.</span><button className="button secondary" onClick={load}>Load latest application</button></div>}
    {application&&<><header className="detail-header"><div><span className="program-code">{application.program.code} · {application.program.title}</span><h1>{application.projectTitle}</h1></div><StatusBadge status={application.status}/></header>
      <div className="workflow-panel"><p>{messages[application.status]}</p>{editable(application.status)&&<div className="action-row"><Link className="button secondary" to={`/applications/${application.id}/edit`}>Edit</Link><button className="button" disabled={submitting} onClick={submit}>{submitting?'Submitting…':application.status==='DRAFT'?'Submit':'Resubmit'}</button></div>}</div>
      <section className="content-panel"><h2>Application information</h2><dl className="information-grid"><div><dt>Applicant organization</dt><dd>{application.applicantOrganizationName}</dd></div><div><dt>Requested amount</dt><dd>{formatMoney(application.requestedAmount)}</dd></div><div className="wide"><dt>Short summary</dt><dd>{application.shortSummary}</dd></div><div className="wide"><dt>Detailed plan</dt><dd>{application.detailedPlan}</dd></div><div><dt>Created</dt><dd>{formatTimestamp(application.createdAt)}</dd></div><div><dt>Updated</dt><dd>{formatTimestamp(application.updatedAt)}</dd></div></dl></section>
      <section className="content-panel"><h2>Attachments</h2>{attachmentError!==undefined&&<ErrorNotice error={attachmentError}/>} {editable(application.status)&&<form className="upload-form" onSubmit={upload}><label>Supporting file<input name="file" type="file" required disabled={uploading}/></label><button className="button secondary" disabled={uploading}>{uploading?'Uploading…':'Upload'}</button></form>}
        {attachments.length===0?<p className="muted">No attachments.</p>:<div className="attachment-list">{attachments.map((f)=><div key={f.id}><div><strong>{f.filename}</strong><small>{f.contentType} · {f.size===null?'Size pending':formatBytes(f.size)} · {f.status} · {formatTimestamp(f.createdAt)}</small></div><div className="action-row">{f.status==='AVAILABLE'&&<button className="text-button" onClick={()=>download(f)}>Download</button>}{editable(application.status)&&<button className="text-button danger" onClick={()=>remove(f.id)}>Delete</button>}</div></div>)}</div>}</section>
      <section className="content-panel"><h2>Status history</h2>{history.length===0?<p className="muted">No status changes recorded.</p>:<ol className="timeline">{history.map((h)=><li key={h.id}><time>{formatTimestamp(h.changedAt)}</time><strong>{h.fromStatus?`${h.fromStatus} → `:''}{h.toStatus}</strong>{h.reason&&<p>{h.reason}</p>}</li>)}</ol>}</section></>}
  </section>
}
const formatBytes=(size:number)=>size<1024?`${size} B`:size<1048576?`${(size/1024).toFixed(1)} KB`:`${(size/1048576).toFixed(1)} MB`
