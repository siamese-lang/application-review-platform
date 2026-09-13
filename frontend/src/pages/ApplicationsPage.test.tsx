import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { ApplicationsPage } from './ApplicationsPage'
const response=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json'}})
afterEach(()=>vi.unstubAllGlobals())
describe('ApplicationsPage',()=>{
 it('shows loading then an empty result',async()=>{vi.stubGlobal('fetch',vi.fn().mockResolvedValue(response({items:[],page:0,size:20,totalElements:0,totalPages:0})));render(<MemoryRouter><ApplicationsPage/></MemoryRouter>);expect(screen.getByRole('status')).toHaveTextContent('신청 내역을 불러오는 중');expect(await screen.findByRole('heading',{name:'신청 내역이 없습니다'})).toBeInTheDocument()})
 it('renders populated applicant applications',async()=>{vi.stubGlobal('fetch',vi.fn().mockResolvedValue(response({items:[{id:3,program:{id:1,code:'OPEN-1',title:'Open Fund'},projectTitle:'Community project',requestedAmount:12000,status:'DRAFT',version:0,createdAt:'2026-01-01T00:00:00Z',updatedAt:'2026-01-02T00:00:00Z'}],page:0,size:20,totalElements:1,totalPages:1})));render(<MemoryRouter><ApplicationsPage/></MemoryRouter>);expect(await screen.findByText('Community project')).toBeInTheDocument();expect(screen.getAllByText('작성 중').some((element) => element.classList.contains('status'))).toBe(true);expect(screen.getByRole('link',{name:'상세 보기'})).toHaveAttribute('href','/applications/3')})
})
