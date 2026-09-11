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

  it('discards the invalidated logout token before the next unsafe request', async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(jsonResponse({ headerName: 'X-CSRF-TOKEN', parameterName: '_csrf', token: 'token-a' }))
      .mockResolvedValueOnce(jsonResponse({ id: 7, role: 'APPLICANT' }))
      .mockResolvedValueOnce(jsonResponse({ headerName: 'X-CSRF-TOKEN', parameterName: '_csrf', token: 'token-b' }))
      .mockResolvedValueOnce(new Response(null, { status: 204 }))
      .mockResolvedValueOnce(jsonResponse({ headerName: 'X-CSRF-TOKEN', parameterName: '_csrf', token: 'token-c' }))
      .mockResolvedValueOnce(jsonResponse({ id: 7, role: 'APPLICANT' }))
    vi.stubGlobal('fetch', fetchMock)
    await api.login({ username: 'alex', password: 'correct-password' }); await api.logout(); await api.login({ username: 'alex', password: 'correct-password' })
    expect(fetchMock.mock.calls.map(([path]) => path)).toEqual(['/api/v1/auth/csrf', '/api/v1/auth/login', '/api/v1/auth/csrf', '/api/v1/auth/logout', '/api/v1/auth/csrf', '/api/v1/auth/login'])
    expect(new Headers((fetchMock.mock.calls[5][1] as RequestInit).headers).get('X-CSRF-TOKEN')).toBe('token-c')
  })

  it('uploads only the file in FormData without setting multipart content type', async () => {
    const fetchMock = vi.fn().mockResolvedValueOnce(jsonResponse({ headerName: 'X-CSRF-TOKEN', parameterName: '_csrf', token: 'token' })).mockResolvedValueOnce(jsonResponse({ id: 1, filename: 'evidence.txt' }))
    vi.stubGlobal('fetch', fetchMock); const file = new File(['proof'], 'evidence.txt', { type: 'text/plain' }); await api.uploadAttachment(9, file)
    const init = fetchMock.mock.calls[1][1] as RequestInit
    expect(init.body).toBeInstanceOf(FormData); expect(Array.from((init.body as FormData).keys())).toEqual(['file']); expect(new Headers(init.headers).has('Content-Type')).toBe(false)
  })

  it('sends structured application create fields', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValueOnce(jsonResponse({ headerName: 'X-CSRF-TOKEN', parameterName: '_csrf', token: 'token' })).mockResolvedValueOnce(jsonResponse({ id: 8 })))
    const body = { programId: 1, applicantOrganizationName: 'Org', projectTitle: 'Project', shortSummary: 'Summary', requestedAmount: 1000, detailedPlan: 'Plan' }
    await api.createApplication(body)
    expect(JSON.parse((vi.mocked(fetch).mock.calls[1][1] as RequestInit).body as string)).toEqual(body)
  })

  it('exposes ProblemDetail errors', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(jsonResponse({ title: 'Conflict', status: 409, detail: 'Username already exists' }, 409)))
    try {
      await api.programs()
      throw new Error('Expected api.programs() to reject')
    } catch (error) {
      expect(error).toBeInstanceOf(ApiError)
      expect(error).toMatchObject({ status: 409, message: 'Username already exists' })
    }
  })
})
