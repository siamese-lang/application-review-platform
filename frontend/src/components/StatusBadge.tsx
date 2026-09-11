import type { IntakeStatus } from '../types/api'

const labels: Record<IntakeStatus, string> = {
  SCHEDULED: 'Scheduled',
  OPEN: 'Open for applications',
  CLOSED: 'Closed',
}

export function StatusBadge({ status }: { status: IntakeStatus }) {
  return <span className={`status status-${status.toLowerCase()}`}>{labels[status]}</span>
}
