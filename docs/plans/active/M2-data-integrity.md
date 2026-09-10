# M2 Data Integrity — Execution Plan

Status: ACTIVE

## Goal

Harden the completed M1 business workflow so authorization is difficult to bypass accidentally, relational mutations remain atomic, concurrent updates cannot silently overwrite one another, application mutations are auditable, and authenticated HTTP sessions are stored in PostgreSQL through Spring Session JDBC.

M2 strengthens the existing M1 workflow. It does not redesign the M0 state machine or begin attachment, cloud-deployment, observability, workload, performance, reliability, backup, or DR work.

## Baseline and confirmed gaps

M1 already provides DB-backed BCrypt authentication, applicant/reviewer route restrictions, service-layer ownership and role checks, the frozen application state machine, reviewer assignment, and transactional status-history creation.

The M2 gaps confirmed on `main` are:

- `applications` has no optimistic-lock version column and `Application` has no JPA `@Version` field.
- There is no `audit_events` table or application-mutation audit model.
- HTTP session state is still the default servlet session; Spring Session JDBC is not configured.
- Application detail/history authorization is a two-step caller pattern (`get` followed by a separate visibility check), which can be bypassed accidentally by future callers.
- The `ADMIN` role exists but has no minimal operational read path for users, applications, status history, or audit events.
- Existing M1 tests do not prove optimistic-lock conflicts, persisted rollback behavior, audit consistency, or PostgreSQL-backed session reuse.

## Scope

### 1. Authorization hardening

- Keep the authenticated server-side principal as the only authority for user identity and role.
- Refactor public application read APIs so applicant/reviewer detail and history access require the acting `User` in the service call; do not expose an unguarded public application-detail path to web callers.
- Preserve ownership checks for applicant mutations and assigned-reviewer checks for review decisions.
- Add `/admin/**` authorization for `ADMIN` only.
- Provide minimal read-only ADMIN visibility into users, applications, application status history, and application audit events. Do not expose password hashes, session data, credentials, or other secret-bearing fields.
- Add negative tests proving cross-owner, cross-reviewer, wrong-role, and non-admin access are rejected without data mutation.

### 2. Transaction and history integrity

- Keep application mutation rules in domain/service code, not controllers/templates.
- Application status change, its `application_status_history` row, and its audit event must commit or roll back as one relational transaction.
- Application create/edit and their audit events must also share the service transaction.
- Failed authorization, invalid transitions, validation failures, and optimistic-lock conflicts must not leave partial application, history, or audit state.
- Keep status history as the canonical transition trail. Make history reads deterministic when timestamps tie, using the row id as the secondary order if needed.
- Do not replace the current relational transaction model with distributed transactions, queues, or compensating infrastructure.

### 3. Optimistic locking

- Add `applications.version` with an additive Flyway migration and map it with JPA `@Version` on `Application`.
- Use ordinary JPA/Hibernate optimistic locking; do not introduce pessimistic locking as the default workflow.
- A concurrent write must fail rather than silently overwrite a committed update.
- Translate an optimistic-lock conflict at the web boundary to a controlled HTTP 409 response without exposing an internal stack trace.
- Add a PostgreSQL integration test using independent transactions/entity instances to demonstrate that competing updates cannot both commit and that the losing transaction leaves no extra history/audit rows.

### 4. Application audit events

Add an append-only `audit_events` relational table for successful application mutations. The minimum fields are:

- `id`
- `application_id` — FK to `applications`
- `actor_id` — FK to `users`
- `event_type`
- `occurred_at`

Minimum event types:

- `APPLICATION_CREATED`
- `APPLICATION_EDITED`
- `APPLICATION_SUBMITTED`
- `REVIEW_STARTED`
- `REVISION_REQUESTED`
- `APPLICATION_APPROVED`
- `APPLICATION_REJECTED`

Status history remains responsible for `from_status`, `to_status`, transition actor/time, and required revision/rejection reason. Audit events must not duplicate full application content, passwords, credentials, session identifiers, request bodies, or other sensitive payloads.

Login-success/failure auditing, authorization-denial auditing, a generic enterprise audit framework, and audit export are not required in M2.

### 5. Spring Session JDBC

- Add the Spring Boot 4.1.x JDBC session starter (`spring-boot-starter-session-jdbc`) and use the existing PostgreSQL `DataSource`.
- Let Spring Boot auto-configure JDBC-backed `HttpSession`; do not add manual `@EnableJdbcHttpSession` unless a verified framework requirement makes it necessary.
- Manage `SPRING_SESSION` and `SPRING_SESSION_ATTRIBUTES` through Flyway using the PostgreSQL schema compatible with the Spring Session version resolved by the project.
- Set Spring Session JDBC schema initialization to `never` so Flyway remains the single schema-management mechanism.
- Keep CSRF enabled.
- Add an integration test that performs a real form login, verifies a PostgreSQL session row is created for the authenticated principal, and proves a subsequent request can reuse the issued session cookie.
- Do not add Redis or another session store, and do not create `app-02` in M2.

### 6. Minimal ADMIN operational read visibility

Provide only the read capability required by the frozen product definition. A minimal server-rendered surface may include:

- user list showing safe identity/role fields only;
- application list/detail;
- status history for an application;
- audit events for an application.

No user management, role editing, reviewer reassignment, application mutation, configuration console, or broad administration suite is part of M2.

## Database migrations

- Do not modify `V1__m1_business_schema.sql` after it has shipped.
- Add new Flyway migration(s) for M2.
- Prefer one additive migration for `applications.version` and `audit_events`, and a separate clearly named migration for the Spring Session PostgreSQL tables.
- Preserve expand/additive migration behavior; no destructive column/table removal is needed.
- Primary, foreign-key-supporting, unique, integrity, and official Spring Session indexes are allowed. Do not add speculative composite performance indexes.
- Hibernate remains schema validation only; it must not create or update the production schema.

## Likely files / components

Implementation is expected to touch multiple components, including:

- `app/pom.xml`
- `app/src/main/resources/application.yml`
- `app/src/main/resources/db/migration/`
- `Application` and new audit domain model/event type
- application/history/audit repositories
- `ApplicationService` and a minimal ADMIN read service if useful
- `SecurityConfig`
- applicant/reviewer controllers only where required by the hardened service API
- minimal ADMIN controller/templates
- `WebExceptionHandler` for optimistic-lock conflict handling
- existing M1 tests plus new M2 integration/security/session/concurrency tests

The exact file split may change during implementation as long as this scope and the frozen architectural boundaries are preserved.

## Out of scope

Do not pull the following into M2:

- attachments, Garage, attachment metadata/reconciliation, or object-storage consistency (M3)
- GCP VM/network provisioning, OpenTofu/Ansible deployment, Nginx, `ops-01`, or `app-02` (M4+)
- CI/CD deployment, rollback automation, pgBackRest implementation, or recovery exercises (M5+)
- Prometheus/Loki/Tempo/Grafana/Alertmanager/Alloy (M6)
- synthetic volume generation or k6 (M7)
- performance tuning or speculative indexes (M8)
- fault injection/reliability scenarios (M9)
- PITR/full DR (M10)
- Redis, Kafka, RabbitMQ, Kubernetes, Keycloak, Elasticsearch, microservices, or another datastore
- `review_comments` unless a separately approved requirement makes them necessary

No ADR is expected for the planned M2 work because optimistic locking, audit events, PostgreSQL, and Spring Session JDBC are already part of the frozen baseline. If implementation requires changing a frozen boundary, stop that change and propose an ADR first.

## Verification

M2 is not complete unless all of the following are verified against PostgreSQL:

1. All existing M1 workflow and security tests continue to pass.
2. Flyway upgrades a clean database through all migrations and Hibernate schema validation succeeds.
3. Applicant ownership and role checks reject unauthorized reads and writes.
4. Reviewer visibility/assignment rules reject unauthorized reads and decisions.
5. ADMIN read routes/services are ADMIN-only and do not expose password hashes or session data.
6. A successful status transition persists application state, exactly one status-history row, and exactly one corresponding audit event in the same transaction.
7. Failed/invalid operations leave application state, history count, and audit count unchanged.
8. Competing writes through independent transactions demonstrate optimistic locking; only the winner persists and the loser leaves no partial history/audit state.
9. Revision/rejection reasons remain correctly stored in status history.
10. Successful create/edit/submit/review actions create the expected audit event types.
11. A form login creates a Spring Session JDBC row in PostgreSQL and the issued session cookie authenticates a later request.
12. CSRF and existing login/route restrictions remain enabled and functional.
13. `./mvnw verify` passes in GitHub Actions with PostgreSQL on the exact final PR head.
14. Repository-baseline CI remains green and no M3+ or unapproved architecture change appears in the diff.

## Execution workflow

After this plan is reviewed and merged to `main`:

1. Create a fresh M2 implementation branch from the then-current `main`.
2. Use Codex as the preferred workspace for the substantive multi-file implementation.
3. Codex must read `AGENTS.md`, `README.md`, `docs/WORKFLOW.md`, the frozen M0 documents, and this plan before editing.
4. During implementation, use current upstream framework documentation when Spring Boot/Spring Session/Hibernate behavior is version-sensitive rather than guessing.
5. Open an M2 PR, inspect its actual diff, and require GitHub Actions on the exact final head.
6. For CI failures, diagnose the first causal failure before making the smallest required change.
7. Only after every M2 done condition is met, move this plan to `docs/plans/completed/`, update README to M2 complete/M3 next, rerun CI on that final head, merge, and verify post-merge `main` CI.

## Done when

M2 is done only when the authorization hardening, transactional/history/audit integrity, optimistic locking, PostgreSQL-backed Spring Session, and minimal ADMIN read visibility are implemented and verified; all existing behavior remains green; the final PR contains no M3+ scope; this plan is moved to completed; README reflects M2 completion; the final PR head passes required Actions; and the merged `main` workflow succeeds.
