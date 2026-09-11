import type { ApplicationStatus, IntakeStatus } from '../types/api'

const labels: Record<IntakeStatus | ApplicationStatus, string> = {
  SCHEDULED: 'Scheduled',
  OPEN: 'Open for applications',
  CLOSED: 'Closed',
  DRAFT: 'Draft',
  SUBMITTED: 'Submitted',
  IN_REVIEW: 'In review',
  NEEDS_REVISION: 'Needs revision',
  APPROVED: 'Approved',
  REJECTED: 'Rejected',
}

export function StatusBadge({ status }: { status: IntakeStatus | ApplicationStatus }) {
  return <span className={`status status-${status.toLowerCase().replace('_', '-')}`}>{labels[status]}</span>
}
