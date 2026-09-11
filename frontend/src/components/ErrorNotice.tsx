import { ApiError } from '../api/client'

export function errorMessage(error: unknown) {
  if (error instanceof ApiError) return error.problem.detail || error.problem.title || error.message
  if (error instanceof Error) return error.message
  return 'An unexpected error occurred. Please try again.'
}

export function ErrorNotice({ error }: { error: unknown }) {
  return <div className="notice error" role="alert"><strong>We could not complete that request.</strong><span>{errorMessage(error)}</span></div>
}
