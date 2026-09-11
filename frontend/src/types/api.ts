export interface ApiPage<T> {
  items: T[]
  page: number
  size: number
  totalElements: number
  totalPages: number
}

export type IntakeStatus = 'SCHEDULED' | 'OPEN' | 'CLOSED'

export interface PublicProgram {
  id: number
  code: string
  title: string
  description: string
  applicationOpenAt: string
  applicationCloseAt: string
  intakeStatus: IntakeStatus
}

export interface CurrentUser {
  id: number
  username: string
  displayName: string
  email: string
  role: 'APPLICANT' | 'REVIEWER' | 'ADMIN'
}

export interface RegisterRequest {
  username: string
  password: string
  displayName: string
  email: string
}

export interface LoginRequest {
  username: string
  password: string
}

export interface CsrfResponse {
  headerName: string
  parameterName: string
  token: string
}

export interface ProblemDetail {
  type?: string
  title?: string
  status?: number
  detail?: string
  instance?: string
  [extension: string]: unknown
}
