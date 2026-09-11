import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { ApplicationDetailPage } from './ApplicationDetailPage'
const response=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json'}})
const detail=(status:string)=>({id:4,program:{id:1,code:'OPEN-1',title:'Open Fund'},applicantOrganizationName:'Applicant Org',projectTitle:'Project',shortSummary:'Summary',requestedAmount:100,status,version:2,detailedPlan:'Plan',createdAt:'2026-01-01T00:00:00Z',updatedAt:'2026-01-02T00:00:00Z'})
function mock(status:string,submit?:()=>Promise<Response>){vi.stubGlobal('fetch',vi.fn((path:string,init?:RequestInit)=>{if(path.endsWith('/history'))return Promise.resolve(response([{id:1,changedAt:'2026-01-02T00:00:00Z',fromStatus:'IN_REVIEW',toStatus:'NEEDS_REVISION',reason:'Add a signed budget'}]));if(path.endsWith('/attachments'))return Promise.resolve(response([]));if(path.endsWith('/submit')&&init?.method==='POST')return submit!();return Promise.resolve(response(detail(status)))}))}
function view(){return render(<MemoryRouter initialEntries={['/applications/4']}><Routes><Route path="/applications/:applicationId" element={<ApplicationDetailPage/>}/></Routes></MemoryRouter>)}
afterEach(()=>{ cleanup(); vi.unstubAllGlobals() })
describe('ApplicationDetailPage',()=>{
 for(const [status,action] of [['DRAFT','Submit'],['NEEDS_REVISION','Resubmit']] as const)it(`shows editable ${status} actions and history reason`,async()=>{mock(status);view();expect(await screen.findByRole('link',{name:'Edit'})).toBeInTheDocument();expect(screen.getByRole('button',{name:action})).toBeInTheDocument();expect(screen.getByText('Add a signed budget')).toBeInTheDocument()})
 for(const status of ['SUBMITTED','IN_REVIEW','APPROVED','REJECTED'])it(`keeps ${status} read only`,async()=>{mock(status);view();await screen.findByText('Project');expect(screen.queryByRole('link',{name:'Edit'})).not.toBeInTheDocument();expect(screen.queryByRole('button',{name:/submit/i})).not.toBeInTheDocument()})
 it('shows a 409 conflict without retrying submit',async()=>{const submit=vi.fn().mockResolvedValue(response({title:'Conflict',status:409,detail:'Stale application version'},409));mock('DRAFT',submit);view();fireEvent.click(await screen.findByRole('button',{name:'Submit'}));expect(await screen.findByText(/changed before the action/)).toBeInTheDocument();expect(submit).toHaveBeenCalledTimes(1);await waitFor(()=>expect(screen.getByRole('button',{name:'Load latest application'})).toBeInTheDocument())})
})
