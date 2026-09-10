# DOMAIN — M0 Frozen Baseline

Status: FROZEN

## Application states

`DRAFT`, `SUBMITTED`, `IN_REVIEW`, `NEEDS_REVISION`, `APPROVED`, `REJECTED`.

## Allowed transitions

| From | To | Actor |
|---|---|---|
| DRAFT | SUBMITTED | APPLICANT |
| SUBMITTED | IN_REVIEW | REVIEWER |
| IN_REVIEW | NEEDS_REVISION | REVIEWER |
| NEEDS_REVISION | SUBMITTED | APPLICANT |
| IN_REVIEW | APPROVED | REVIEWER |
| IN_REVIEW | REJECTED | REVIEWER |

`APPROVED` and `REJECTED` are terminal.

## Rules

- An applicant may modify only their own application and only while its status is `DRAFT` or `NEEDS_REVISION`.
- On the first successful `SUBMITTED → IN_REVIEW` transition, the reviewer becomes the assigned reviewer for subsequent review decisions. Complex reassignment is out of scope.
- Concurrent reviewer updates must not silently overwrite one another. `applications.version` is used for optimistic locking.
- Every status transition records `from_status`, `to_status`, `changed_by`, `changed_at`, and `reason` when applicable.
- `NEEDS_REVISION` and `REJECTED` require a reason.
- Attachments are mutable only in `DRAFT` and `NEEDS_REVISION`.
- Authentication identifies the caller; service/domain code still enforces ownership and authorization for the target resource.

## Transactional expectation

A successful state change and its status-history row are one relational transaction: both commit or both roll back.
