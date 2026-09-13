import { describe, expect, it } from 'vitest'
import { applicationStatusLabels, attachmentStatusLabels, auditEventLabels, auditSubjectLabels, formatDateTime, formatMoney, intakeStatusLabels, publicationStatusLabels, roleLabels } from './presentation'

describe('Korean presentation helpers', () => {
  it('provides shared Korean business labels', () => {
    expect(applicationStatusLabels).toMatchObject({ DRAFT: '작성 중', SUBMITTED: '제출 완료', IN_REVIEW: '심사 중', NEEDS_REVISION: '보완 요청', APPROVED: '승인', REJECTED: '반려' })
    expect(intakeStatusLabels).toEqual({ SCHEDULED: '접수 예정', OPEN: '접수 중', CLOSED: '접수 마감' })
    expect(roleLabels).toEqual({ APPLICANT: '신청자', REVIEWER: '심사자', ADMIN: '관리자' })
    expect(publicationStatusLabels).toEqual({ DRAFT: '작성 중', PUBLISHED: '게시 완료' })
    expect(attachmentStatusLabels).toEqual({ PENDING: '처리 중', AVAILABLE: '업로드 완료', FAILED: '처리 실패', DELETE_PENDING: '삭제 중' })
    expect(auditSubjectLabels).toEqual({ APPLICATION: '신청서', PROGRAM: '지원사업', USER: '사용자' })
    expect(auditEventLabels.REVIEW_STARTED).toBe('심사 시작')
  })

  it('formats money and timestamps with the Korean locale', () => {
    expect(formatMoney(1250000)).toBe('1,250,000원')
    expect(formatDateTime('2026-09-12T03:30:00Z')).toMatch(/2026.*9.*12/)
  })
})
