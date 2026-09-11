import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { api } from '../api/client'
import { ErrorNotice } from '../components/ErrorNotice'
import { StatusBadge } from '../components/StatusBadge'
import type { ApiPage, PublicProgram } from '../types/api'

export function formatDate(value: string) {
  return new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value))
}

export function ProgramsPage() {
  const [result, setResult] = useState<ApiPage<PublicProgram>>()
  const [error, setError] = useState<unknown>()

  useEffect(() => { api.programs().then(setResult).catch(setError) }, [])

  return <section className="page">
    <div className="page-heading"><div><div className="eyebrow">Published opportunities</div><h1>Programs</h1><p>Explore currently published support programs and their intake windows.</p></div></div>
    {!result && !error && <div className="notice" role="status">Loading programs…</div>}
    {error && <ErrorNotice error={error} />}
    {result?.items.length === 0 && <div className="empty"><h2>No published programs</h2><p>There are no opportunities to show right now. Please check again later.</p></div>}
    {result && result.items.length > 0 && <div className="program-grid">
      {result.items.map((program) => <article className="program-card" key={program.id}>
        <div className="card-top"><span className="program-code">{program.code}</span><StatusBadge status={program.intakeStatus} /></div>
        <h2><Link to={`/programs/${program.id}`}>{program.title}</Link></h2>
        <p className="description">{program.description}</p>
        <dl className="dates"><div><dt>Opens</dt><dd>{formatDate(program.applicationOpenAt)}</dd></div><div><dt>Closes</dt><dd>{formatDate(program.applicationCloseAt)}</dd></div></dl>
        <Link className="text-link" to={`/programs/${program.id}`}>View program details <span aria-hidden="true">→</span></Link>
      </article>)}
    </div>}
    {result && result.totalPages > 1 && <p className="pagination-summary">Showing page {result.page + 1} of {result.totalPages} · {result.totalElements} programs</p>}
  </section>
}
