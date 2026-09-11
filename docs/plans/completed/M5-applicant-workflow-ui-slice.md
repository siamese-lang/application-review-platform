# M5 Applicant Workflow UI Slice

## Goal

Add the applicant-facing React workflow over the existing `/api/v1` application and attachment contracts.

## Files/Components

- Frontend API DTO types and typed client
- Applicant route guard, navigation, list, create, detail, edit, attachments, and history UI
- Public Program detail entry link and focused frontend tests
- M5 implementation checkpoint/order

## Constraints

- No backend, schema, dependency, workflow-job, reviewer/admin UI, or later-milestone changes.
- Treat client guards and action visibility as UX only; backend authorization and workflow rules remain authoritative.
- Preserve optimistic versions, ProblemDetail responses, same-origin sessions, and CSRF behavior.

## Verification

- `npm run typecheck`, `npm test -- --run`, and `npm run build` in `frontend/`
- Repository baseline, backend tests, and infrastructure static checks

