import type { ApplicationStatus, AttachmentStatus, AuditEventType, IntakeStatus, ProgramPublicationStatus, Role } from '../types/api'

export const applicationStatusLabels: Record<ApplicationStatus, string> = {
  DRAFT: '작성 중', SUBMITTED: '제출 완료', IN_REVIEW: '심사 중',
  NEEDS_REVISION: '보완 요청', APPROVED: '승인', REJECTED: '반려',
}
export const intakeStatusLabels: Record<IntakeStatus, string> = {
  SCHEDULED: '접수 예정', OPEN: '접수 중', CLOSED: '접수 마감',
}
export const roleLabels: Record<Role, string> = { APPLICANT: '신청자', REVIEWER: '심사자', ADMIN: '관리자' }
export const publicationStatusLabels: Record<ProgramPublicationStatus, string> = { DRAFT: '작성 중', PUBLISHED: '게시 완료' }
export const attachmentStatusLabels: Record<AttachmentStatus, string> = { PENDING: '처리 중', AVAILABLE: '업로드 완료', FAILED: '처리 실패', DELETE_PENDING: '삭제 중' }
export const auditSubjectLabels = { APPLICATION: '신청서', PROGRAM: '지원사업', USER: '사용자' } as const
export const auditEventLabels: Record<AuditEventType, string> = {
  APPLICATION_CREATED: '신청서 작성', APPLICATION_EDITED: '신청서 수정', APPLICATION_SUBMITTED: '신청서 제출',
  REVIEW_STARTED: '심사 시작', REVISION_REQUESTED: '보완 요청', APPLICATION_APPROVED: '신청 승인',
  APPLICATION_REJECTED: '신청 반려', USER_REGISTERED: '사용자 가입', PROGRAM_CREATED: '지원사업 생성',
  PROGRAM_UPDATED: '지원사업 수정', PROGRAM_PUBLISHED: '지원사업 게시',
}

export const formatDateTime = (value: string) => new Intl.DateTimeFormat('ko-KR', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value))
export const formatMoney = (value: number) => `${new Intl.NumberFormat('ko-KR', { maximumFractionDigits: 2 }).format(value)}원`
export const applicationStatusLabel = (status: ApplicationStatus) => applicationStatusLabels[status]
