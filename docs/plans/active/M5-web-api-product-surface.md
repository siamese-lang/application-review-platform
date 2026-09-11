# M5 Web/API & Product Surface — Execution Plan

Status: ACTIVE

## Goal

Turn the verified M1–M4 backend/runtime baseline into a credible browser-based support-program application and review system before delivery automation, observability, load, performance, reliability, and DR work are built around the wrong web boundary.

M5 establishes a production-like browser/application contract and user-facing product surface: public program discovery, applicant self-registration, session-secured browser API semantics, a versioned REST API, a React/TypeScript SPA, realistic application/review screens, and enough structured account/business data to make the system recognizable as an application/review workflow rather than a generic CRUD demo.

M5 does not add microservices, JWT merely for appearance, a separate frontend runtime server, Kubernetes, managed application services, fake external identity integrations, notifications, enterprise organization administration, or unrelated UI complexity.

## Why this milestone is inserted now

M4 proved the existing application can run on the split-role GCP topology, but the browser surface remains intentionally minimal and the current domain/account representation is too thin for later operations/performance work to represent a convincing application/review system.

If the REST/frontend/account boundary is postponed until after delivery automation, observability, and workload design, those later milestones would need to be partially rebuilt. M5 therefore precedes Operations.

Future milestone order after this rebaseline:

- M5 Web/API & Product Surface
- M6 Operations & Delivery
- M7 Observability
- M8 Workload
- M9 Performance
- M10 Reliability
- M11 DR
- M12 Portfolio

Completed M0–M4 milestone identities and evidence are not renumbered.

## Architecture decisions

Implementation follows:

- `docs/architecture/ADR-001-web-api-spa.md` for the browser/API boundary;
- `docs/architecture/ADR-002-account-lifecycle.md` for registration and privileged-account provisioning;
- `docs/architecture/ADR-003-program-lifecycle.md` for administrator program publication, intake admission, reviewer claim-on-start, and generalized audit subjects.

Target browser path:

```text
Browser
  │ HTTPS, one origin
  ▼
edge-01: Nginx
  ├─ /, /assets/**     → versioned React/Vite static build
  └─ /api/v1/**        → app-01: Spring Boot REST API
                              ├─ PostgreSQL
                              └─ Garage S3 API
```

The frontend is a build artifact, not a long-running Node service in production. Nginx remains the only public ingress. The Spring application remains a modular monolith; existing domain/service rules remain authoritative.

## Pre-implementation design freeze

ADR-001, ADR-002, and ADR-003 together define the M5 implementation baseline. The pre-implementation architecture review is complete after ADR-003.

Do not reopen the architecture merely because implementation exposes a cosmetic preference or an opportunity to add another technology. Change the baseline only when a concrete implementation/test result or newly discovered business requirement proves an accepted decision incorrect or incomplete. Such a change requires an explicit ADR or plan amendment before code is built around it.

## Current implementation checkpoint

Checkpoint date: 2026-09-11

Verified applicant API baseline after PR #20: `91658ba7da432cb3f7ba8a20d137e32078f2ced2`  
PR #20 exact-head workflow `34583818541` and post-merge workflow `34584088613` — `repository-baseline`, `m1-application` (43 tests on the PR head), and `m4-infrastructure-static` all successful.

Completed slices:

- PR #15 — M5 schema/domain foundation
  - Flyway V5 user/program/application enrichment;
  - deterministic synthetic backfill;
  - generalized application/program/user audit subjects;
  - JPA mappings and M1–M4 regression compatibility.
- PR #16 — M5 business services
  - applicant registration service;
  - ADMIN program draft/edit/publish lifecycle;
  - server-side intake-window admission rule;
  - structured application edits and conflict semantics;
  - exclusive reviewer claim-on-start concurrency verification.
- PR #17 — M5 authentication and Program REST boundary
  - API/web Spring Security chain separation;
  - CSRF bootstrap;
  - JSON registration/login/logout/current-user API;
  - Spring Session JDBC session persistence;
  - JSON 401/403 and ProblemDetail error handling;
  - public published-program API;
  - ADMIN Program REST API.
- PR #20 — applicant Application and Attachment REST boundary
  - paginated applicant-owned application list with optional status filtering;
  - structured create/detail/edit with DTOs and client-observed optimistic version checks;
  - version-aware submit/resubmit and status-history API;
  - attachment list/upload/streamed download/delete over the existing M3 Garage lifecycle;
  - CSRF/role/ownership/state/admission/conflict integration coverage;
  - no schema migration or speculative performance index.
- Reviewer queue/detail/claim/decision and attachment APIs, remaining ADMIN operational read APIs, and the React/Vite public/auth shell are present on the current baseline.
- The applicant workflow React slice now covers guarded list/create/detail/edit routes, version-aware submission, attachments, history, and public Program entry.
- The reviewer workflow React slice now covers guarded queue/detail routes, active-work filtering and pagination, version-aware claim-on-start, conflict recovery, decisions, read-only attachments, and history.

The next implementation slice is:

1. ADMIN program and operational screens;
2. real-stack applicant/reviewer browser E2E;
3. Nginx SPA routing validation and Thymeleaf presentation cleanup.

### Relationship to later DB/SQL evidence

M5 owns schema quality, constraints, transactions, concurrency, and the API query contract. It does **not** claim that the project's SQL/query-performance gap is solved and it must not add speculative performance indexes.

Per `docs/PROJECT_EXECUTION.md`:

- M8 Workload creates representative synthetic data/workloads large enough to expose real query behavior;
- M9 Performance captures actual SQL and PostgreSQL `EXPLAIN (ANALYZE, BUFFERS)`, identifies measured bottlenecks, applies evidence-supported query/index changes through Flyway, and retains same-condition before/after evidence.

This preserves the project-wide rule to measure before optimizing.

## Scope

### 1. Applicant identity and public entry flow

The final product must have a coherent unauthenticated-to-authenticated entry path:

`public program discovery → applicant registration/login → private application workflow`.

Implement public self-registration for `APPLICANT` only.

Minimum registration data:

- unique username/login ID;
- password;
- display name;
- synthetic email/contact address.

Rules:

- registration never accepts an authoritative role selection;
- the server always assigns `APPLICANT`;
- passwords are validated and persisted only as hashes through the repository `PasswordEncoder`;
- duplicate username/email conflicts use structured API errors;
- successful registration and login are separate operations;
- public users may read program list/detail but may not access private applications;
- successful registration records a non-secret audit event.

`REVIEWER` and `ADMIN` do not have public self-registration. They remain controlled bootstrap/operations identities for this synthetic project and authenticate through the same session infrastructure after provisioning.

Do not simulate email verification, password-reset email, MFA, SSO/OIDC, or reviewer invitation delivery without a real external provider. Document these as production gaps.

### 2. Program administration and intake lifecycle

Support programs are no longer seed-only reference records in the finished product.

Implement administrator commands for:

- create a program as `DRAFT`;
- edit a draft program;
- publish a valid draft program.

Rules:

- only `ADMIN` may create/edit/publish programs;
- `DRAFT` programs are not visible through the public API;
- `PUBLISHED` programs are publicly discoverable;
- program code is unique and immutable;
- `application_open_at < application_close_at` is mandatory before publication;
- scheduled/open/closed intake state is derived from publication status and timestamps, not stored independently;
- new application creation is allowed only for a published program while `application_open_at <= now < application_close_at`;
- closing intake does not hide existing applications or prevent a reviewer-requested resubmission of an already accepted application;
- published programs are immutable through ordinary M5 commands and cannot be silently unpublished;
- draft program edits use optimistic locking.

Retain the existing reviewer pull queue. A reviewer claims an unassigned `SUBMITTED` application by successfully starting review. Do not add administrator reviewer assignment/reassignment or multi-reviewer panels in M5. Concurrent claims must result in only one effective assigned reviewer.

### 3. Minimal product/domain enrichment

The current `Program(title, description)`, `Application(title, content, status)`, and `User(username, password_hash, role)` models are too sparse for a convincing support-program workflow. Add only fields that materially improve the business/browser contract.

Planned additive user model:

- display name;
- synthetic email/contact address;
- created timestamp;
- updated timestamp;
- existing username/password hash/role retained.

Planned additive program model:

- stable unique program code;
- title;
- description;
- publication status (`DRAFT`, `PUBLISHED`);
- application-open timestamp;
- application-close timestamp;
- optimistic-lock version;
- created timestamp;
- updated timestamp.

Planned additive application model:

- applicant organization name;
- project title;
- short summary;
- requested amount;
- detailed plan/content;
- existing status/reviewer/version/timestamps.

Existing status-history `reason` continues to hold revision/approval/rejection rationale where appropriate; do not add a separate comment subsystem unless the implemented workflow demonstrates a concrete need.

Generalize the M2 `audit_events` target so one event can refer to exactly one application, program, or user while retaining explicit foreign keys and a database exactly-one-subject check. Existing application events remain valid. Add `USER_REGISTERED`, `PROGRAM_CREATED`, `PROGRAM_UPDATED`, and `PROGRAM_PUBLISHED`.

Use Flyway only. Prefer additive migrations and preserve rollback compatibility where practical. Backfill existing synthetic users/programs/applications with deterministic synthetic values as needed.

All data remains synthetic; do not introduce real personal or company data.

### 4. REST API boundary

Add controllers under a dedicated API package. Controllers translate HTTP DTOs to existing application/domain services; they do not own state-transition rules.

Use `/api/v1` as the browser API namespace.

Minimum contract areas:

- authentication/session: register applicant, current user, login, logout, CSRF bootstrap;
- public programs: published list/detail with derived intake state;
- admin programs: list/detail/create/edit/publish;
- applicant applications: list/detail/create/edit/submit/resubmit;
- attachments: upload/list/download/delete within existing lifecycle rules;
- reviewer work queue: list/detail/start review/request revision/approve/reject;
- admin operational views: program administration plus user/application/audit visibility and workflow counts.

Use explicit request/response DTOs rather than serializing JPA entities. List endpoints that may grow must use explicit pagination/filter DTOs rather than exposing repository internals.

Business transition endpoints may use action-oriented commands where that represents the domain more clearly than pretending a review decision is generic CRUD.

Return structured JSON errors using Spring `ProblemDetail` or an equivalent repository-wide shape. Authentication failures, authorization failures, validation failures, duplicate-account conflicts, not-found cases, state-transition conflicts, and optimistic-lock conflicts must be distinguishable.

### 5. Concurrency and integrity over HTTP

Preserve M2 optimistic locking. Editable application requests carry the client-observed version and stale writes fail with HTTP 409 rather than silently overwriting newer state.

Draft program edits also carry the client-observed version and stale administrator writes fail with HTTP 409.

Reviewer claim-on-start must remain exclusive under concurrent attempts; the losing claim is surfaced as a conflict rather than overwriting the assigned reviewer.

Account uniqueness must be enforced by database constraints as well as application validation; pre-insert existence checks alone are not concurrency-safe.

Attachment state/reconciliation semantics from M3 remain unchanged behind the API.

Do not weaken authorization because the SPA hides buttons. Every ownership/role/state check remains server-side.

### 6. Browser authentication and CSRF

Keep Spring Security session authentication and Spring Session JDBC. Do not replace it with JWT solely because the client is React.

Production remains same-origin through Nginx:

- SPA and API share one HTTPS origin;
- session cookie is Secure, HttpOnly, and appropriately SameSite-scoped;
- unsafe methods remain CSRF protected;
- expose a small CSRF bootstrap mechanism suitable for the SPA, while keeping the session identifier inaccessible to JavaScript;
- API unauthenticated/forbidden responses are JSON rather than HTML redirects.

Registration does not create a privileged session or role. Login establishes the session after credentials are authenticated.

Local frontend development should use the Vite development proxy for `/api` so browser requests remain same-origin from the developer's perspective. Do not add permissive wildcard CORS merely to make development work. If an actual cross-origin client is later introduced, add a narrow allowlist and test it then.

### 7. React/TypeScript frontend

Create a `frontend/` application using React, TypeScript, and Vite with a committed lockfile. Keep the dependency set small.

Do not add Redux or another global-state framework unless concrete state complexity demonstrates a need. Server state should be fetched through a small typed API client layer; authentication/session state should remain simple.

Minimum screens:

- public program list/detail;
- applicant registration;
- login;
- applicant dashboard;
- application create/edit form with business sections rather than one raw textarea;
- my applications list with status/filter cues;
- application detail with workflow step/status, attachments, and history;
- reviewer queue with filtering/sorting/pagination;
- reviewer detail with applicant content, attachment access, history, and allowed review actions;
- admin dashboard plus program list/create/edit/publish screens and user/application/audit read views.

The target is a restrained internal/public-sector business-system UI: readable tables, forms, status badges, navigation, empty/error/loading states, and responsive layout. It is not a design-showcase SPA.

### 8. Frontend/backend contract tests

Backend verification must include controller/API integration tests for registration, authentication, authorization, validation, transitions, stale-version conflicts, attachments, and structured error responses.

Program lifecycle tests must prove:

- only admin can create/edit/publish programs;
- draft programs are absent from public discovery;
- invalid windows cannot be published;
- published programs expose derived scheduled/open/closed intake state;
- direct API calls cannot create applications for draft, scheduled, or closed programs;
- reviewer-requested resubmission remains valid after intake closes;
- stale program edits conflict;
- concurrent reviewer claims have only one winner;
- generalized audit rows have exactly one valid subject.

Identity tests must prove:

- public program read works before authentication;
- applicant registration always creates `APPLICANT`;
- role escalation through registration is impossible;
- duplicate username/email is rejected;
- plaintext password is not stored/returned;
- a registered applicant can then log in through the normal JDBC-backed session;
- applicant sessions cannot access reviewer/admin APIs;
- controlled reviewer/admin accounts still authenticate normally.

Frontend verification must include at least:

- TypeScript/build checks;
- focused component tests for critical state/error rendering;
- browser-level end-to-end tests for one applicant flow and one reviewer flow against a real application test stack.

The applicant E2E must begin as an unauthenticated browser user, discover a public program, register/login, then execute the private application workflow. Browser tests must exercise API/session/CSRF behavior, not mock the entire backend.

### 9. Static serving and routing contract

Prepare Nginx/application configuration for the later M6 deployment model:

- `/api/` proxies to private `app-01`;
- SPA assets are served directly by Nginx;
- client-side routes fall back to `index.html` without swallowing `/api` errors;
- fingerprinted assets may be cached long-term;
- `index.html` must not be cached in a way that pins users to obsolete asset references;
- security headers and request-size limits must remain explicit;
- attachment upload limits must be consistent across Nginx and Spring.

M5 may validate this contract locally/in CI. M6 owns the real delivery automation and re-deployment to GCP.

### 10. Migration away from Thymeleaf UI

Do not maintain two permanent presentation implementations.

During M5, existing Thymeleaf pages may remain temporarily as a migration safety net while REST endpoints and SPA flows are built. Before M5 completion, the supported browser path must be the SPA/API path and obsolete Thymeleaf-specific controllers/templates should be removed or explicitly reduced to a narrowly justified fallback.

Domain/service code must not be rewritten merely because the presentation layer changes.

## Explicit non-goals

M5 does not introduce:

- microservices or a backend-for-frontend service;
- JWT/OAuth server/Keycloak;
- a Node/Next.js production server or SSR;
- a separate frontend VM;
- WebSockets;
- email/SMS notifications;
- email verification/password-reset delivery/MFA/real identity proofing;
- reviewer/admin public signup or a simulated invitation service;
- complex workflow designer/dynamic form builder;
- enterprise tenant/organization hierarchy;
- post-publication program amendment/republication workflow;
- administrator reviewer assignment/reassignment or multi-reviewer panels;
- Redis, Kafka/RabbitMQ, Elasticsearch;
- performance tuning before M9;
- observability stack before M7;
- GCP redeployment automation before M6.

## Implementation order

1. **DONE** — Add ADR-002/ADR-003-approved user, program, application, and generalized audit fields through additive Flyway migrations.
2. **DONE** — Extend domain/repository/service code for applicant registration, program lifecycle/admission rules, structured application fields, and generalized audit subjects.
3. **DONE** — Implement admin program create/edit/publish APIs and public published-program discovery.
4. **DONE** — Implement applicant registration/session API contracts.
5. **DONE** — Implement applicant application/attachment APIs including intake-window and optimistic-lock conflict semantics.
6. **DONE** — Implement reviewer queue/claim/decision APIs and remaining admin operational read APIs.
7. **DONE for current API surface; extend consistently as later endpoints are added** — Establish JSON error, CSRF, and API 401/403 behavior.
8. **DONE** — Build the typed React/Vite client and public/registration/login shell.
9. **DONE** — Build applicant workflow screens.
10. **DONE (reviewer); NEXT (admin)** — Build reviewer screens and admin program/operational screens.
11. Add backend integration, frontend component/build, and real-stack browser E2E coverage.
12. Validate Nginx SPA/API routing contract locally/CI.
13. Remove obsolete Thymeleaf presentation paths before M5 completion.

Do not move to M6 merely because the SPA renders; the full identity/business/API verification below must pass.

## Verification

M5 is not complete unless all of the following hold:

1. API contract is versioned under `/api/v1` and JPA entities are not exposed directly.
2. Existing domain/service authorization and transition tests remain green.
3. Additive Flyway migrations create the approved user/program/application fields, generalized audit subjects, and preserve existing data through deterministic synthetic backfill.
4. An admin can create/edit a draft program and publish it only with a valid application window; draft programs remain private.
5. A published program is publicly discoverable and its scheduled/open/closed intake state is derived correctly.
6. New application creation is rejected for draft, scheduled, or closed programs even when the API is called directly.
7. Reviewer-requested revision/resubmission remains valid for an existing application after intake closes.
8. Stale draft-program edits and concurrent reviewer claim losers produce conflicts rather than lost updates.
9. Generalized audit rows enforce exactly one user/program/application subject and existing application audit behavior remains green.
10. An unauthenticated browser can browse public published-program list/detail.
11. A user can self-register only as `APPLICANT`; privileged role self-assignment is impossible.
12. Duplicate/invalid registration produces structured errors and passwords are persisted only as hashes.
13. A newly registered applicant can log in using the normal Spring Security/Spring Session JDBC path.
14. Applicant can create/edit an application, upload/download an attachment, submit, revise after a revision request, and view final status through the SPA/API path.
15. Reviewer can filter the queue, open a submission, start review, request revision, approve, or reject as allowed.
16. Admin can inspect agreed read-only operational views.
17. Stale application edits return a conflict and do not overwrite newer data.
18. Session authentication, logout, JSON 401/403 handling, and CSRF protection work through the SPA.
19. Applicant sessions cannot access reviewer/admin APIs; bootstrap reviewer/admin identities continue to authenticate normally.
20. Production routing is designed as same-origin; no wildcard CORS is introduced.
21. Frontend build/type checks and critical component tests pass.
22. Browser E2E covers the public discovery → registration/login → applicant workflow and a reviewer workflow against the real backend test stack.
23. Nginx SPA fallback does not intercept `/api` responses and static/API routing is verified.
24. The supported browser UI is recognizably an application/review business system rather than raw HTML/debug pages.
25. Obsolete Thymeleaf presentation code is removed or explicitly justified before milestone completion.
26. No fake external identity/messaging integration and no M6+ implementation is pulled into M5.
27. Exact final PR head passes required GitHub Actions, the plan is moved to completed, and post-merge `main` is green.

## Handoff to M6

M6 Operations & Delivery will consume the M5 contract rather than redesign it. It will build/version backend and frontend artifacts from one source revision, deploy the frontend static release to `edge-01` and the backend JAR to `app-01`, manage migration/deployment order and rollback, add CI/CD and backup basics, and reproduce the M4 split-role environment as needed for verified delivery evidence.
