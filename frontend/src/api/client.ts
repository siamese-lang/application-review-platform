import type {
  ApiPage,
  CsrfResponse,
  CurrentUser,
  LoginRequest,
  ProblemDetail,
  PublicProgram,
  RegisterRequest,
} from '../types/api'

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly problem: ProblemDetail,
  ) {
    super(problem.detail || problem.title || `Request failed (${status})`)
    this.name = 'ApiError'
  }
}

let csrf: CsrfResponse | undefined

async function readProblem(response: Response): Promise<ProblemDetail> {
  const contentType = response.headers.get('content-type') ?? ''
  if (contentType.includes('json')) {
    const body: unknown = await response.json()
    if (body && typeof body === 'object') return body as ProblemDetail
  }
  return { title: response.statusText, status: response.status, detail: 'The request could not be completed.' }
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const method = (init.method ?? 'GET').toUpperCase()
  const headers = new Headers(init.headers)

  if (!['GET', 'HEAD', 'OPTIONS', 'TRACE'].includes(method)) {
    csrf ??= await request<CsrfResponse>('/api/v1/auth/csrf')
    headers.set(csrf.headerName, csrf.token)
  }
  if (init.body && !(init.body instanceof FormData) && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json')
  }

  const response = await fetch(path, { ...init, headers, credentials: 'same-origin' })
  if (!response.ok) throw new ApiError(response.status, await readProblem(response))
  if (response.status === 204) return undefined as T
  return response.json() as Promise<T>
}

export const api = {
  programs: (page = 0, size = 20) =>
    request<ApiPage<PublicProgram>>(`/api/v1/programs?page=${page}&size=${size}`),
  program: (id: string | number) => request<PublicProgram>(`/api/v1/programs/${id}`),
  currentUser: () => request<CurrentUser>('/api/v1/auth/me'),
  register: (registration: RegisterRequest) =>
    request<CurrentUser>('/api/v1/auth/register', { method: 'POST', body: JSON.stringify(registration) }),
  login: async (credentials: LoginRequest) => {
    const user = await request<CurrentUser>('/api/v1/auth/login', {
      method: 'POST',
      body: JSON.stringify(credentials),
    })
    csrf = undefined
    return user
  },
  logout: () => request<void>('/api/v1/auth/logout', { method: 'POST' }),
}

export function clearCsrfTokenForTests() {
  csrf = undefined
}
