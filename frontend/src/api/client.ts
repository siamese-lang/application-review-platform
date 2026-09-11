import type {
  ApiPage,
  CsrfResponse,
  CurrentUser,
  LoginRequest,
  ProblemDetail,
  PublicProgram,
  RegisterRequest,
  ApplicationCreateRequest, ApplicationDetail, ApplicationHistory, ApplicationListItem,
  ApplicationStatus, ApplicationUpdateRequest, Attachment,
  ReviewerApplicationDetail, ReviewerQueueItem,
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

async function download(path: string): Promise<{ blob: Blob; filename?: string }> {
  const response = await fetch(path, { credentials: 'same-origin' })
  if (!response.ok) throw new ApiError(response.status, await readProblem(response))
  const disposition = response.headers.get('content-disposition') ?? ''
  const encoded = disposition.match(/filename\*=UTF-8''([^;]+)/i)?.[1]
  const quoted = disposition.match(/filename="([^"]+)"/i)?.[1]
  return { blob: await response.blob(), filename: encoded ? decodeURIComponent(encoded) : quoted }
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
  logout: async () => {
    await request<void>('/api/v1/auth/logout', { method: 'POST' })
    csrf = undefined
  },
  applications: (page = 0, size = 20, status?: ApplicationStatus) => {
    const query = new URLSearchParams({ page: String(page), size: String(size) })
    if (status) query.set('status', status)
    return request<ApiPage<ApplicationListItem>>(`/api/v1/applications?${query}`)
  },
  application: (id: string | number) => request<ApplicationDetail>(`/api/v1/applications/${id}`),
  createApplication: (body: ApplicationCreateRequest) => request<ApplicationDetail>('/api/v1/applications', { method: 'POST', body: JSON.stringify(body) }),
  updateApplication: (id: string | number, body: ApplicationUpdateRequest) => request<ApplicationDetail>(`/api/v1/applications/${id}`, { method: 'PUT', body: JSON.stringify(body) }),
  submitApplication: (id: string | number, version: number) => request<ApplicationDetail>(`/api/v1/applications/${id}/submit`, { method: 'POST', body: JSON.stringify({ version }) }),
  applicationHistory: (id: string | number) => request<ApplicationHistory[]>(`/api/v1/applications/${id}/history`),
  attachments: (id: string | number) => request<Attachment[]>(`/api/v1/applications/${id}/attachments`),
  uploadAttachment: (id: string | number, file: File) => { const body = new FormData(); body.append('file', file); return request<Attachment>(`/api/v1/applications/${id}/attachments`, { method: 'POST', body }) },
  downloadAttachment: (applicationId: string | number, attachmentId: number) => download(`/api/v1/applications/${applicationId}/attachments/${attachmentId}`),
  deleteAttachment: (applicationId: string | number, attachmentId: number) => request<void>(`/api/v1/applications/${applicationId}/attachments/${attachmentId}`, { method: 'DELETE' }),
  reviewQueue: (page = 0, size = 20, status?: 'SUBMITTED' | 'IN_REVIEW') => {
    const query = new URLSearchParams({ page: String(page), size: String(size) })
    if (status) query.set('status', status)
    return request<ApiPage<ReviewerQueueItem>>(`/api/v1/review/applications?${query}`)
  },
  reviewerApplication: (id: string | number) => request<ReviewerApplicationDetail>(`/api/v1/review/applications/${id}`),
  startReview: (id: string | number, version: number) => request<ReviewerApplicationDetail>(`/api/v1/review/applications/${id}/start`, { method: 'POST', body: JSON.stringify({ version }) }),
  requestRevision: (id: string | number, version: number, reason: string) => request<ReviewerApplicationDetail>(`/api/v1/review/applications/${id}/request-revision`, { method: 'POST', body: JSON.stringify({ version, reason }) }),
  approveApplication: (id: string | number, version: number) => request<ReviewerApplicationDetail>(`/api/v1/review/applications/${id}/approve`, { method: 'POST', body: JSON.stringify({ version }) }),
  rejectApplication: (id: string | number, version: number, reason: string) => request<ReviewerApplicationDetail>(`/api/v1/review/applications/${id}/reject`, { method: 'POST', body: JSON.stringify({ version, reason }) }),
  reviewerHistory: (id: string | number) => request<ApplicationHistory[]>(`/api/v1/review/applications/${id}/history`),
  reviewerAttachments: (id: string | number) => request<Attachment[]>(`/api/v1/review/applications/${id}/attachments`),
  downloadReviewerAttachment: (applicationId: string | number, attachmentId: number) => download(`/api/v1/review/applications/${applicationId}/attachments/${attachmentId}`),
}

export function clearCsrfTokenForTests() {
  csrf = undefined
}
