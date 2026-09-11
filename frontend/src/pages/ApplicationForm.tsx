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
    if (edit && applicationId) api.application(applicationId).then((a) => {
      setValues({ programId: a.program.id, applicantOrganizationName: a.applicantOrganizationName, projectTitle: a.projectTitle, shortSummary: a.shortSummary, requestedAmount: a.requestedAmount, detailedPlan: a.detailedPlan }); setVersion(a.version); setProgram(a.program)
    }).catch(setError).finally(() => setLoading(false))
    else if (programId > 0) { setValues((v) => ({ ...v, programId })); api.program(programId).then(setProgram).catch(setError) }
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
  if (loading) return <section className="page"><div className="notice" role="status">Loading application…</div></section>
  return <section className="page form-page"><Link className="back-link" to={edit ? `/applications/${applicationId}` : '/applications'}>← Back</Link><div className="page-heading"><div className="eyebrow">Applicant workspace</div><h1>{edit ? 'Edit application' : 'New application'}</h1></div>
    {error !== undefined && <ErrorNotice error={error} />}{conflict && <div className="conflict-actions"><strong>This application was changed by another request.</strong><span>Your entries have been kept. Reload the latest version before deciding how to apply them.</span><button className="button secondary" type="button" onClick={() => window.location.reload()}>Load latest application</button></div>}
    <form className="business-form" onSubmit={submit}>
      <label>Program{program ? <span className="selected-program">{program.code} — {program.title}</span> : <input name="programId" type="number" min="1" required disabled={edit} value={values.programId || ''} onChange={(e) => field('programId', e.target.value)} />}</label>
      <label>Applicant organization name<input name="applicantOrganizationName" required maxLength={255} value={values.applicantOrganizationName} onChange={(e) => field('applicantOrganizationName', e.target.value)} /></label>
      <label>Project title<input name="projectTitle" required maxLength={255} value={values.projectTitle} onChange={(e) => field('projectTitle', e.target.value)} /></label>
      <label>Short summary<textarea name="shortSummary" required maxLength={1000} rows={4} value={values.shortSummary} onChange={(e) => field('shortSummary', e.target.value)} /></label>
      <label>Requested amount<input name="requestedAmount" type="number" min="0.01" step="0.01" required value={values.requestedAmount || ''} onChange={(e) => field('requestedAmount', e.target.value)} /></label>
      <label>Detailed plan<textarea name="detailedPlan" required maxLength={10000} rows={12} value={values.detailedPlan} onChange={(e) => field('detailedPlan', e.target.value)} /></label>
      <button className="button" disabled={submitting}>{submitting ? 'Saving…' : edit ? 'Save changes' : 'Save draft'}</button>
    </form></section>
}
