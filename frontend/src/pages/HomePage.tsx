import { Link } from 'react-router-dom'

export function HomePage() {
  return <section className="hero page"><div className="eyebrow">Support program portal</div><h1>Find the right program for your next project.</h1><p>Review published opportunities, confirm application dates, and create an applicant account when you are ready.</p><Link className="button" to="/programs">Browse programs</Link></section>
}
