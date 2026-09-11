import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { api } from '../api/client'
import { ErrorNotice } from '../components/ErrorNotice'
import { StatusBadge } from '../components/StatusBadge'
import type { PublicProgram } from '../types/api'
import { formatDate } from './ProgramsPage'

export function ProgramDetailPage() {
  const { programId } = useParams()
  const [program, setProgram] = useState<PublicProgram>()
  const [error, setError] = useState<unknown>()
  useEffect(() => { if (programId) api.program(programId).then(setProgram).catch(setError) }, [programId])

  return <section className="page detail-page">
    <Link className="back-link" to="/programs">← All programs</Link>
    {!program && !error && <div className="notice" role="status">Loading program details…</div>}
    {error && <ErrorNotice error={error} />}
    {program && <article>
      <div className="detail-header"><div><span className="program-code">{program.code}</span><h1>{program.title}</h1></div><StatusBadge status={program.intakeStatus} /></div>
      <div className="detail-layout"><div className="detail-copy"><h2>About this program</h2><p>{program.description}</p></div><aside><h2>Application period</h2><dl className="dates stacked"><div><dt>Opens</dt><dd>{formatDate(program.applicationOpenAt)}</dd></div><div><dt>Closes</dt><dd>{formatDate(program.applicationCloseAt)}</dd></div></dl><p className="aside-note">Application creation will be available in a later product slice.</p></aside></div>
    </article>}
  </section>
}
