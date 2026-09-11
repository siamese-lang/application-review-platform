import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { afterEach, expect, it, vi } from 'vitest'
import { AuthProvider } from '../auth/AuthContext'
import { LoginPage } from './LoginPage'
import { clearCsrfTokenForTests } from '../api/client'

afterEach(() => { vi.unstubAllGlobals(); clearCsrfTokenForTests() })

it('logs in and establishes UI auth state from the login response', async () => {
  const fetchMock = vi.fn()
    .mockResolvedValueOnce(new Response(JSON.stringify({ title: 'Unauthorized', status: 401, detail: 'Authentication is required' }), { status: 401, headers: { 'Content-Type': 'application/problem+json' } }))
    .mockResolvedValueOnce(new Response(JSON.stringify({ headerName: 'X-CSRF-TOKEN', parameterName: '_csrf', token: 'token' }), { headers: { 'Content-Type': 'application/json' } }))
    .mockResolvedValueOnce(new Response(JSON.stringify({ id: 2, username: 'applicant', displayName: 'Applicant One', email: 'applicant@example.test', role: 'APPLICANT' }), { headers: { 'Content-Type': 'application/json' } }))
  vi.stubGlobal('fetch', fetchMock)
  render(<MemoryRouter initialEntries={['/login']}><AuthProvider><Routes><Route path="/login" element={<LoginPage />} /><Route path="/programs" element={<h1>Programs destination</h1>} /></Routes></AuthProvider></MemoryRouter>)
  const user = userEvent.setup()
  await user.type(screen.getByLabelText('Username'), 'applicant')
  await user.type(screen.getByLabelText('Password'), 'correct-password')
  await user.click(screen.getByRole('button', { name: 'Log in' }))
  expect(await screen.findByRole('heading', { name: 'Programs destination' })).toBeInTheDocument()
})
