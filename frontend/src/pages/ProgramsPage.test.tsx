import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { ProgramsPage } from './ProgramsPage'

const response = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })
afterEach(() => vi.unstubAllGlobals())

describe('ProgramsPage', () => {
  it('renders public programs from the ApiPage contract', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(response({ items: [{ id: 4, code: 'GREEN-2026', title: 'Green Growth Fund', description: 'Funding for synthetic green projects.', applicationOpenAt: '2026-09-01T00:00:00Z', applicationCloseAt: '2026-10-01T00:00:00Z', intakeStatus: 'OPEN' }], page: 0, size: 20, totalElements: 1, totalPages: 1 })))
    render(<MemoryRouter><ProgramsPage /></MemoryRouter>)
    expect(screen.getByRole('status')).toHaveTextContent('지원사업을 불러오는 중')
    expect(await screen.findByRole('heading', { name: 'Green Growth Fund' })).toBeInTheDocument()
    expect(screen.getByText('접수 중')).toBeInTheDocument()
  })

  it('renders the empty state', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(response({ items: [], page: 0, size: 20, totalElements: 0, totalPages: 0 })))
    render(<MemoryRouter><ProgramsPage /></MemoryRouter>)
    expect(await screen.findByRole('heading', { name: '게시된 지원사업이 없습니다' })).toBeInTheDocument()
  })

  it('renders ProblemDetail errors for people', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(response({ title: 'Service Unavailable', status: 503, detail: 'Programs are temporarily unavailable' }, 503)))
    render(<MemoryRouter><ProgramsPage /></MemoryRouter>)
    expect(await screen.findByRole('alert')).toHaveTextContent('Programs are temporarily unavailable')
  })
})
