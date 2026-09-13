import type { ApplicationStatus, IntakeStatus } from '../types/api'
import { applicationStatusLabels, intakeStatusLabels } from '../utils/presentation'

export function StatusBadge({ status }: { status: IntakeStatus | ApplicationStatus }) {
  const label = status in intakeStatusLabels ? intakeStatusLabels[status as IntakeStatus] : applicationStatusLabels[status as ApplicationStatus]
  return <span className={`status status-${status.toLowerCase().replace('_', '-')}`}>{label}</span>
}
