import { Link } from 'react-router-dom'

export function HomePage() {
  return <section className="hero page"><div className="eyebrow">지원사업 통합 서비스</div><h1>필요한 지원사업을 찾고 신청하세요.</h1><p>게시된 지원사업과 접수 기간을 확인하고, 신청서를 작성해 심사 결과까지 한곳에서 관리할 수 있습니다.</p><Link className="button" to="/programs">지원사업 찾아보기</Link></section>
}
