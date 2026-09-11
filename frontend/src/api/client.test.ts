import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { api, ApiError, clearCsrfTokenForTests } from './client'

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })
}

describe('API client', () => {
  beforeEach(() => clearCsrfTokenForTests())
  afterEach(() => vi.unstubAllGlobals())

  it('adds the server-provided CSRF header and same-origin credentials to unsafe requests', async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(jsonResponse({ headerName: 'X-CSRF-TOKEN', parameterName: '_csrf', token: 'safe-token' }))
      .mockResolvedValueOnce(jsonResponse({ id: 7, username: 'alex', displayName: 'Alex', email: 'alex@example.test', role: 'APPLICANT' }))
    vi.stubGlobal('fetch', fetchMock)

    await api.login({ username: 'alex', password: 'correct-password' })

    expect(fetchMock).toHaveBeenNthCalledWith(1, '/api/v1/auth/csrf', expect.objectContaining({ credentials: 'same-origin' }))
    const loginInit = fetchMock.mock.calls[1][1] as RequestInit
    expect(new Headers(loginInit.headers).get('X-CSRF-TOKEN')).toBe('safe-token')
    expect(loginInit.credentials).toBe('same-origin')
  })

  it('refreshes the CSRF token after login before logout', async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(jsonResponse({ headerName: 'X-CSRF-TOKEN', parameterName: '_csrf', token: 'token-a' }))
      .mockResolvedValueOnce(jsonResponse({ id: 7, username: 'alex', displayName: 'Alex', email: 'alex@example.test', role: 'APPLICANT' }))
      .mockResolvedValueOnce(jsonResponse({ headerName: 'X-CSRF-TOKEN', parameterName: '_csrf', token: 'token-b' }))
      .mockResolvedValueOnce(new Response(null, { status: 204 }))
    vi.stubGlobal('fetch', fetchMock)

    await api.login({ username: 'alex', password: 'correct-password' })
    await api.logout()

    expect(fetchMock).toHaveBeenCalledTimes(4)
    expect(fetchMock.mock.calls.map(([path]) => path)).toEqual([
      '/api/v1/auth/csrf',
      '/api/v1/auth/login',
      '/api/v1/auth/csrf',
      '/api/v1/auth/logout',
    ])
    const loginHeaders = new Headers((fetchMock.mock.calls[1][1] as RequestInit).headers)
    const logoutHeaders = new Headers((fetchMock.mock.calls[3][1] as RequestInit).headers)
    expect(loginHeaders.get('X-CSRF-TOKEN')).toBe('token-a')
    expect(logoutHeaders.get('X-CSRF-TOKEN')).toBe('token-b')
  })

  it('registration sends only the public registration contract without a role', async () => {
    vi.stubGlobal('fetch', vi.fn()
      .mockResolvedValueOnce(jsonResponse({ headerName: 'X-CSRF-TOKEN', parameterName: '_csrf', token: 'token' }))
      .mockResolvedValueOnce(jsonResponse({ id: 1, username: 'new-user', displayName: 'New User', email: 'new@example.test', role: 'APPLICANT' })))

    await api.register({ username: 'new-user', password: 'twelve-characters', displayName: 'New User', email: 'new@example.test' })
    const body = JSON.parse((vi.mocked(fetch).mock.calls[1][1] as RequestInit).body as string)
    expect(body).toEqual({ username: 'new-user', password: 'twelve-characters', displayName: 'New User', email: 'new@example.test' })
    expect(body).not.toHaveProperty('role')
  })

  it('exposes ProblemDetail errors', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(jsonResponse({ title: 'Conflict', status: 409, detail: 'Username already exists' }, 409)))
    await expect(api.programs()).rejects.toEqual(expect.objectContaining<ApiError>({ status: 409, message: 'Username already exists' }))
  })
})
