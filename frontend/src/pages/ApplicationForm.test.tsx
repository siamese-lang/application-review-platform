import { StrictMode } from 'react'
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { ApplicationForm } from './ApplicationForm'

const response = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

const detail = (shortSummary: string) => ({
  id: 4,
  program: { id: 1, code: 'OPEN-1', title: 'Open Fund' },
  applicantOrganizationName: 'Applicant Org',
  projectTitle: 'Project',
  shortSummary,
  requestedAmount: 100,
  detailedPlan: 'Plan',
  status: 'DRAFT',
  version: 2,
  createdAt: '2026-01-01T00:00:00Z',
  updatedAt: '2026-01-02T00:00:00Z',
})

afterEach(() => {
  cleanup()
  vi.unstubAllGlobals()
})

describe('ApplicationForm', () => {
  it('does not let a stale StrictMode load overwrite user edits', async () => {
    let resolveFirst!: (value: Response) => void
    const first = new Promise<Response>((resolve) => { resolveFirst = resolve })
    let applicationReads = 0

    vi.stubGlobal('fetch', vi.fn((path: string) => {
      if (path === '/api/v1/applications/4') {
        applicationReads += 1
        if (applicationReads === 1) return first
        return Promise.resolve(response(detail('Loaded summary')))
      }
      throw new Error(`Unexpected request: ${path}`)
    }))

    render(
      <StrictMode>
        <MemoryRouter initialEntries={['/applications/4/edit']}>
          <Routes>
            <Route path="/applications/:applicationId/edit" element={<ApplicationForm edit />} />
          </Routes>
        </MemoryRouter>
      </StrictMode>,
    )

    const summary = await screen.findByLabelText('Short summary')
    expect(summary).toHaveValue('Loaded summary')

    fireEvent.change(summary, { target: { value: 'User edit in progress' } })
    expect(summary).toHaveValue('User edit in progress')

    resolveFirst(response(detail('Stale first load')))

    await waitFor(() => expect(summary).toHaveValue('User edit in progress'))
    expect(applicationReads).toBe(2)
  })
})
