import { Link } from 'react-router-dom'
export function NotFoundPage() { return <section className="page empty"><h1>페이지를 찾을 수 없습니다</h1><p>요청하신 페이지가 없거나 주소가 변경되었습니다.</p><Link className="button" to="/programs">지원사업 보기</Link></section> }
