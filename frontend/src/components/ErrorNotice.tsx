import { ApiError } from '../api/client'

export function errorMessage(error: unknown) {
  if (error instanceof ApiError) return error.problem.detail || error.problem.title || error.message
  if (error instanceof Error) return error.message
  return '예상하지 못한 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.'
}

export function ErrorNotice({ error }: { error: unknown }) {
  return <div className="notice error" role="alert"><strong>요청을 처리하지 못했습니다.</strong><span>{errorMessage(error)}</span></div>
}
