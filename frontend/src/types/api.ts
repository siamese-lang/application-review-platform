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

export type ApplicationStatus = 'DRAFT' | 'SUBMITTED' | 'IN_REVIEW' | 'NEEDS_REVISION' | 'APPROVED' | 'REJECTED'
export type AttachmentStatus = 'PENDING' | 'AVAILABLE' | 'FAILED' | 'DELETE_PENDING'

export interface ProgramSummary { id: number; code: string; title: string }
export interface ApplicationListItem {
  id: number; program: ProgramSummary; projectTitle: string; requestedAmount: number
  status: ApplicationStatus; version: number; createdAt: string; updatedAt: string
}
export interface ApplicationDetail extends ApplicationListItem {
  applicantOrganizationName: string; shortSummary: string; detailedPlan: string
}
export interface ApplicationHistory {
  id: number; changedAt: string; fromStatus: ApplicationStatus | null; toStatus: ApplicationStatus; reason: string | null
}
export interface ApplicationCreateRequest {
  programId: number; applicantOrganizationName: string; projectTitle: string
  shortSummary: string; requestedAmount: number; detailedPlan: string
}
export interface ApplicationUpdateRequest extends Omit<ApplicationCreateRequest, 'programId'> { version: number }
export interface Attachment {
  id: number; filename: string; contentType: string; size: number | null; status: AttachmentStatus; createdAt: string
}

export interface ReviewerQueueItem {
  id: number; program: ProgramSummary; applicantOrganizationName: string; projectTitle: string
  requestedAmount: number; status: ApplicationStatus; version: number; updatedAt: string
}
export interface ReviewerApplicantSummary { id: number; username: string; displayName: string; email: string }
export interface ReviewerSummary { id: number; username: string; displayName: string }
export interface ReviewerApplicationDetail extends ReviewerQueueItem {
  applicant: ReviewerApplicantSummary; reviewer: ReviewerSummary | null
  shortSummary: string; detailedPlan: string; createdAt: string
}
