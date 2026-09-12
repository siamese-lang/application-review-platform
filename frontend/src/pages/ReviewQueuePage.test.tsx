import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { ReviewQueuePage } from './ReviewQueuePage'

const item = { id: 7, program: { id: 1, code: 'GRANT-1', title: 'Growth Grant' }, applicantOrganizationName: 'Synthetic Works', projectTitle: 'Expansion', requestedAmount: 5000, status: 'SUBMITTED', version: 3, updatedAt: '2026-01-02T00:00:00Z' }
const page = (items: unknown[] = [item], current = 0, totalPages = 1) => ({ items, page: current, size: 20, totalElements: items.length, totalPages })
const response = (body: unknown) => Promise.resolve(new Response(JSON.stringify(body), { status: 200, headers: { 'Content-Type': 'application/json' } }))
function view() { return render(<MemoryRouter><ReviewQueuePage/></MemoryRouter>) }
afterEach(() => { cleanup(); vi.unstubAllGlobals() })

describe('ReviewQueuePage', () => {
  it('moves from loading to a populated oldest-work-first queue', async () => { vi.stubGlobal('fetch', vi.fn(() => response(page()))); view(); expect(screen.getByRole('status')).toHaveTextContent('불러오는 중'); expect(await screen.findByText('Growth Grant')).toBeInTheDocument(); expect(screen.getByText('Synthetic Works')).toBeInTheDocument() })
  it('renders the empty state', async () => { vi.stubGlobal('fetch', vi.fn(() => response(page([])))); view(); expect(await screen.findByText('진행할 심사 업무가 없습니다')).toBeInTheDocument() })
  it.each([['제출 완료', 'SUBMITTED'], ['심사 중', 'IN_REVIEW']])('requests the %s filter', async (label, status) => { const fetch = vi.fn(() => response(page([]))); vi.stubGlobal('fetch', fetch); view(); await screen.findByText('진행할 심사 업무가 없습니다'); fireEvent.change(screen.getByLabelText('진행 상태'), { target: { value: status } }); await waitFor(() => expect(fetch).toHaveBeenLastCalledWith(expect.stringContaining(`status=${status}`), expect.anything())) })
  it('requests the next page without loading the full result set', async () => { const fetch = vi.fn((url: string) => response(page([item], url.includes('page=1') ? 1 : 0, 2))); vi.stubGlobal('fetch', fetch); view(); fireEvent.click(await screen.findByRole('button', { name: '다음' })); await waitFor(() => expect(fetch).toHaveBeenLastCalledWith(expect.stringContaining('page=1&size=20'), expect.anything())) })
})
