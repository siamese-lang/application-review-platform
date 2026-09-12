import { type FormEvent, useEffect, useState } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { api, ApiError } from '../api/client'
import { ErrorNotice } from '../components/ErrorNotice'
import type { ApplicationCreateRequest, ApplicationDetail, ProgramSummary } from '../types/api'

const blank: ApplicationCreateRequest = { programId: 0, applicantOrganizationName: '', projectTitle: '', shortSummary: '', requestedAmount: 0, detailedPlan: '' }

export function ApplicationForm({ edit = false }: { edit?: boolean }) {
  const { applicationId } = useParams(); const [query] = useSearchParams(); const navigate = useNavigate()
  const [values, setValues] = useState(blank); const [version, setVersion] = useState(0)
  const [program, setProgram] = useState<ProgramSummary>(); const [loading, setLoading] = useState(edit)
  const [submitting, setSubmitting] = useState(false); const [error, setError] = useState<unknown>(); const [conflict, setConflict] = useState(false)
  const programId = Number(query.get('programId'))

  useEffect(() => {
    let cancelled = false
    if (edit && applicationId) {
      setLoading(true)
      api.application(applicationId).then((a) => {
        if (cancelled) return
        setValues({ programId: a.program.id, applicantOrganizationName: a.applicantOrganizationName, projectTitle: a.projectTitle, shortSummary: a.shortSummary, requestedAmount: a.requestedAmount, detailedPlan: a.detailedPlan }); setVersion(a.version); setProgram(a.program)
      }).catch((requestError) => { if (!cancelled) setError(requestError) }).finally(() => { if (!cancelled) setLoading(false) })
    } else if (programId > 0) {
      setValues((v) => ({ ...v, programId }))
      api.program(programId).then((loadedProgram) => { if (!cancelled) setProgram(loadedProgram) }).catch((requestError) => { if (!cancelled) setError(requestError) })
    }
    return () => { cancelled = true }
  }, [applicationId, edit, programId])

  function field(name: keyof ApplicationCreateRequest, value: string) { setValues((v) => ({ ...v, [name]: name === 'programId' || name === 'requestedAmount' ? Number(value) : value })) }
  async function submit(event: FormEvent) {
    event.preventDefault(); setError(undefined); setConflict(false); setSubmitting(true)
    try {
      const saved: ApplicationDetail = edit && applicationId
        ? await api.updateApplication(applicationId, { version, applicantOrganizationName: values.applicantOrganizationName, projectTitle: values.projectTitle, shortSummary: values.shortSummary, requestedAmount: values.requestedAmount, detailedPlan: values.detailedPlan })
        : await api.createApplication(values)
      navigate(`/applications/${saved.id}`)
    } catch (requestError) { setError(requestError); setConflict(requestError instanceof ApiError && requestError.status === 409) } finally { setSubmitting(false) }
  }
  if (loading) return <section className="page"><div className="notice" role="status">신청서를 불러오는 중…</div></section>
  return <section className="page form-page"><Link className="back-link" to={edit ? `/applications/${applicationId}` : '/applications'}>← 돌아가기</Link><div className="page-heading"><div className="eyebrow">신청자 업무</div><h1>{edit ? '신청서 수정' : '새 신청서 작성'}</h1></div>
    {error !== undefined && <ErrorNotice error={error} />}{conflict && <div className="conflict-actions"><strong>다른 작업에서 신청서가 변경되었습니다.</strong><span>입력 내용은 유지했습니다. 최신 신청서를 불러온 뒤 변경 내용을 다시 반영해 주세요.</span><button className="button secondary" type="button" onClick={() => window.location.reload()}>최신 신청서 불러오기</button></div>}
    <form className="business-form" onSubmit={submit}>
      <label>지원사업{program ? <span className="selected-program">{program.code} — {program.title}</span> : <input name="programId" type="number" min="1" required disabled={edit} value={values.programId || ''} onChange={(e) => field('programId', e.target.value)} />}</label>
      <label>신청 기관명<input name="applicantOrganizationName" required maxLength={255} value={values.applicantOrganizationName} onChange={(e) => field('applicantOrganizationName', e.target.value)} /></label>
      <label>과제명<input name="projectTitle" required maxLength={255} value={values.projectTitle} onChange={(e) => field('projectTitle', e.target.value)} /></label>
      <label>요약<textarea name="shortSummary" required maxLength={1000} rows={4} value={values.shortSummary} onChange={(e) => field('shortSummary', e.target.value)} /></label>
      <label>신청 금액(원)<input name="requestedAmount" type="number" min="0.01" step="0.01" required value={values.requestedAmount || ''} onChange={(e) => field('requestedAmount', e.target.value)} /></label>
      <label>세부 계획<textarea name="detailedPlan" required maxLength={10000} rows={12} value={values.detailedPlan} onChange={(e) => field('detailedPlan', e.target.value)} /></label>
      <button className="button" disabled={submitting}>{submitting ? '저장 중…' : edit ? '변경 내용 저장' : '임시 저장'}</button>
    </form></section>
}
