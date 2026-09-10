# M1 Business MVP — Execution Plan

Status: COMPLETED

## Goal

Implement the first end-to-end business workflow of the Application Review Platform using the frozen M0 product/domain/security/data rules, without pulling M2+ infrastructure or reliability concerns forward.

## Scope

- Bootstrap `app/` as a Java 21 + Spring Boot 4.1.1 Maven application.
- Use Spring MVC + Thymeleaf, Spring Security, Spring Data JPA, Flyway, PostgreSQL.
- Implement database-backed users and roles `APPLICANT`, `REVIEWER`, `ADMIN` with BCrypt password verification.
- Implement program list/detail.
- Implement applicant application create/edit/list/detail/submit.
- Implement reviewer submitted-list/detail/start-review/request-revision/approve/reject.
- Persist status history for every successful status transition.
- Enforce the M0 state machine, ownership, reviewer assignment, terminal states, and required reasons.
- Extend GitHub Actions so the application build and tests run on PRs and `main`.

## Data in M1

Create only the relational structures required for M1: users, programs, applications, and application_status_history. Schema changes must be Flyway migrations. Synthetic program rows may be seeded. Do not commit reusable login credentials; tests may create synthetic users programmatically.

## Constraints

- No Garage or attachment implementation (M3).
- No Spring Session JDBC externalization, audit subsystem, or optimistic locking hardening (M2).
- No GCP resources, OpenTofu, Ansible, Nginx, deployment, GHCR delivery, observability, k6, performance tuning, backup, PITR, or DR.
- No Redis, queue, Kafka/RabbitMQ, Kubernetes, Keycloak, React, microservices, or new datastore.
- Keep business rules in domain/service code, not controllers or templates.
- CSRF remains enabled.
- Never trust browser-supplied user IDs or roles for authorization decisions.
- Do not commit secrets or real personal data.
- Prefer a minimal server-rendered UI sufficient to exercise the workflow; visual polish is not an M1 goal.

## Required behavior

### Applicant
- Authenticated applicant can browse programs.
- Applicant can create an application for a program; initial state is `DRAFT` and owner is derived from the authenticated principal.
- Applicant can edit only their own `DRAFT` or `NEEDS_REVISION` application.
- Applicant can submit only their own `DRAFT` or `NEEDS_REVISION` application.
- Successful submission creates a status-history record in the same relational transaction.

### Reviewer
- Reviewer can view applications eligible for review.
- `SUBMITTED -> IN_REVIEW` assigns the acting reviewer.
- Only the assigned reviewer can make subsequent review decisions.
- `IN_REVIEW -> NEEDS_REVISION` requires a nonblank reason.
- `IN_REVIEW -> REJECTED` requires a nonblank reason.
- `IN_REVIEW -> APPROVED` is allowed without a reason.
- `APPROVED` and `REJECTED` are terminal.
- Every successful transition records from_status, to_status, changed_by, changed_at, and reason where applicable.

## Verification

Automated tests must cover at minimum:
- login success/failure with hashed DB-backed user credentials;
- role restrictions on applicant/reviewer routes;
- applicant ownership checks;
- valid and invalid application state transitions;
- reviewer assignment enforcement;
- required revision/rejection reasons;
- terminal-state rejection;
- status/history consistency for successful transitions;
- Flyway migration against PostgreSQL;
- full Maven test/verify execution in GitHub Actions.

Use PostgreSQL for integration verification; do not rely on H2-specific behavior as proof of PostgreSQL correctness. A test-only container/service is acceptable and does not alter the production architecture.

## Done when

- `./mvnw verify` passes in the implementation environment and GitHub Actions.
- The M1 workflow is usable through HTTP/Thymeleaf pages at a functional level.
- No out-of-scope component or architecture change is introduced.
- No secrets or reusable demo credentials are committed.
- This plan is moved to `docs/plans/completed/` before the implementation PR is merged.
