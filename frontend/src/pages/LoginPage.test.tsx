import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { afterEach, expect, it, vi } from 'vitest'
import { AuthProvider } from '../auth/AuthContext'
import { LoginPage } from './LoginPage'
import { clearCsrfTokenForTests } from '../api/client'

afterEach(() => { vi.unstubAllGlobals(); clearCsrfTokenForTests() })

function loginResponses(role: 'APPLICANT' | 'REVIEWER' | 'ADMIN') {
  return vi.fn()
    .mockResolvedValueOnce(new Response(JSON.stringify({ title: 'Unauthorized', status: 401, detail: 'Authentication is required' }), { status: 401, headers: { 'Content-Type': 'application/problem+json' } }))
    .mockResolvedValueOnce(new Response(JSON.stringify({ headerName: 'X-CSRF-TOKEN', parameterName: '_csrf', token: 'token' }), { headers: { 'Content-Type': 'application/json' } }))
    .mockResolvedValueOnce(new Response(JSON.stringify({
      id: 2,
      username: role.toLowerCase(),
      displayName: role,
      email: `${role.toLowerCase()}@example.test`,
      role,
    }), { headers: { 'Content-Type': 'application/json' } }))
}

it('logs in and establishes UI auth state from the login response', async () => {
  const fetchMock = loginResponses('APPLICANT')
  vi.stubGlobal('fetch', fetchMock)
  render(<MemoryRouter initialEntries={['/login']}><AuthProvider><Routes><Route path="/login" element={<LoginPage />} /><Route path="/programs" element={<h1>Programs destination</h1>} /></Routes></AuthProvider></MemoryRouter>)
  const user = userEvent.setup()
  await user.type(screen.getByLabelText('아이디'), 'applicant')
  await user.type(screen.getByLabelText('비밀번호'), 'correct-password')
  await user.click(screen.getByRole('button', { name: '로그인' }))
  expect(await screen.findByRole('heading', { name: 'Programs destination' })).toBeInTheDocument()
})

it('does not return a reviewer to an applicant-only page saved by the previous session', async () => {
  const fetchMock = loginResponses('REVIEWER')
  vi.stubGlobal('fetch', fetchMock)
  render(
    <MemoryRouter initialEntries={[{ pathname: '/login', state: { from: '/applications/12' } }]}>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/review" element={<h1>Reviewer destination</h1>} />
          <Route path="/applications/:applicationId" element={<h1>Applicant destination</h1>} />
        </Routes>
      </AuthProvider>
    </MemoryRouter>,
  )
  const user = userEvent.setup()
  await user.type(screen.getByLabelText('아이디'), 'reviewer')
  await user.type(screen.getByLabelText('비밀번호'), 'correct-password')
  await user.click(screen.getByRole('button', { name: '로그인' }))
  expect(await screen.findByRole('heading', { name: 'Reviewer destination' })).toBeInTheDocument()
  expect(screen.queryByRole('heading', { name: 'Applicant destination' })).not.toBeInTheDocument()
})

it('returns an admin only to an admin page saved before authentication', async () => {
  const fetchMock = loginResponses('ADMIN')
  vi.stubGlobal('fetch', fetchMock)
  render(
    <MemoryRouter initialEntries={[{ pathname: '/login', state: { from: '/admin/users' } }]}>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/admin/users" element={<h1>Admin users destination</h1>} />
        </Routes>
      </AuthProvider>
    </MemoryRouter>,
  )
  const user = userEvent.setup()
  await user.type(screen.getByLabelText('아이디'), 'admin')
  await user.type(screen.getByLabelText('비밀번호'), 'correct-password')
  await user.click(screen.getByRole('button', { name: '로그인' }))
  expect(await screen.findByRole('heading', { name: 'Admin users destination' })).toBeInTheDocument()
})
