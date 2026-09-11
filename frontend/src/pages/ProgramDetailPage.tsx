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
    <Link className="back-link" to="/programs">← All programs</Link>
    {!program && error === undefined && <div className="notice" role="status">Loading program details…</div>}
    {error !== undefined && <ErrorNotice error={error} />}
    {program && <article>
      <div className="detail-header"><div><span className="program-code">{program.code}</span><h1>{program.title}</h1></div><StatusBadge status={program.intakeStatus} /></div>
      <div className="detail-layout"><div className="detail-copy"><h2>About this program</h2><p>{program.description}</p></div><aside><h2>Application period</h2><dl className="dates stacked"><div><dt>Opens</dt><dd>{formatDate(program.applicationOpenAt)}</dd></div><div><dt>Closes</dt><dd>{formatDate(program.applicationCloseAt)}</dd></div></dl>{program.intakeStatus==='OPEN'&&user?.role==='APPLICANT'?<Link className="button full" to={`/applications/new?programId=${program.id}`}>Start application</Link>:program.intakeStatus==='OPEN'&&!user?<p className="aside-note"><Link to="/login" state={{from:`/applications/new?programId=${program.id}`}}>Log in</Link> or <Link to="/register">register</Link> to start an application.</p>:<p className="aside-note">New applications are not accepted at this time.</p>}</aside></div>
    </article>}
  </section>
}
