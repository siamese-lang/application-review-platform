# PROJECT_EXECUTION — Purpose, Evidence Goals, and Working Guardrails

Status: ACTIVE PROJECT BASELINE

This document exists to prevent long implementation sessions, chat history, or tool changes from drifting the project away from its original purpose. It complements `AGENTS.md`, `docs/WORKFLOW.md`, frozen M0 documents, accepted ADRs, and the current active milestone plan.

## 1. Project purpose

Application Review Platform is a personal portfolio project that implements a synthetic support-program application/review workflow and then verifies the system across software, data, delivery, operations, performance, reliability, backup, and recovery concerns.

The project is not trying to maximize the number of technologies or imitate every feature of a real government/financial platform. It is trying to produce a coherent system whose major design choices, failure modes, measurements, and trade-offs can be explained in an interview with evidence.

The final system should be credible enough to describe as:

> A production-like MVP of a support-program application and review platform that implements the core application/review workflow and verifies its web/API, database, storage, delivery, observability, performance, failure, backup, and recovery behavior with synthetic data.

Do not describe it as a production-complete public-sector integrated administration platform.

## 2. What the project must demonstrate

The finished portfolio should contain evidence in the following areas.

### Product and workflow

- public support-program discovery;
- applicant self-registration and session login;
- structured application drafting/editing/submission;
- attachments;
- reviewer work queue and exclusive claim-on-start;
- revision request, resubmission, approval, and rejection;
- administrator program creation/edit/publication;
- workflow history and audit records.

### Application architecture and security

- React/TypeScript/Vite SPA and versioned Spring REST API;
- same-origin Nginx routing;
- Spring Security session authentication and Spring Session JDBC;
- CSRF protection;
- role/ownership/state enforcement on the server;
- modular-monolith boundaries rather than unnecessary distributed services;
- explicit JSON API errors and optimistic-lock conflict handling.

### Database and integrity

This project must provide stronger database evidence than a generic JPA CRUD application.

Required evidence includes:

- relational modeling with PK/FK/UNIQUE/NOT NULL/CHECK constraints;
- Flyway-only schema evolution and deterministic data backfill;
- transaction boundaries that keep state/history/audit changes consistent;
- optimistic locking for stale writes and concurrent reviewer claims;
- referentially constrained audit subjects;
- realistic query behavior measured on representative synthetic data.

The remaining DB/SQL experience gap is **not** considered solved merely because JPA repositories or migrations exist. The later workload/performance milestones must produce direct SQL/query-performance evidence.

### Delivery and operations

- reproducible GCP IaaS topology;
- separate public edge/application/database/object-storage/operations roles as already proven in M4;
- controlled artifact build/deployment and rollback;
- explicit migration/deployment order;
- secret/state handling without committing sensitive material.

### Observability, workload, performance, reliability, and recovery

Later milestones must demonstrate:

- metrics/logs/traces and operational dashboards;
- representative synthetic workloads and data volume;
- measurement before optimization;
- failure experiments with explicit hypotheses and expected blast radius;
- backup and restore evidence;
- recovery verification of business correctness, not only process restart.

## 3. DB/SQL evidence requirement

A known portfolio gap is direct SQL/database-performance experience. M5 improves schema design, integrity, transactions, and concurrency, but it does not by itself close the SQL performance gap.

The project must close that gap in the existing milestone sequence rather than inventing a separate side project:

### M8 Workload

M8 must create representative synthetic data and repeatable workloads large enough to expose real query behavior. Candidate query families include:

- reviewer work queue;
- applicant application list/status view;
- program-level application/status aggregation;
- administrator operational summaries;
- history/audit range queries;
- attachment reconciliation queries.

Do not manufacture complicated SQL solely to look advanced.

### M9 Performance

M9 must select actual measured bottlenecks and retain before/after evidence. For at least one meaningful database path:

1. capture the SQL issued by the application;
2. inspect it with PostgreSQL `EXPLAIN (ANALYZE, BUFFERS)`;
3. identify the measured cause such as sequential scan, sort, poor selectivity, excessive join work, or missing/ineffective index;
4. change query/index design only when the evidence supports it;
5. manage schema/index changes through Flyway;
6. repeat the same workload under comparable conditions;
7. retain actual before/after query-plan and latency evidence.

Do not invent performance numbers and do not add indexes speculatively before measurement.

This is the point at which the project may legitimately claim measured SQL/query-performance improvement.

## 4. Architecture guardrail

The accepted M5 baseline is ADR-001 through ADR-003.

Do not reopen architecture because a technology is fashionable or would make the stack look larger. Architecture changes require a concrete business, operational, implementation, or test reason and the appropriate ADR/plan amendment.

In particular, do not add without a proven requirement:

- microservices;
- JWT merely because the client is React;
- a separate frontend production server/VM;
- Kubernetes;
- Redis;
- Kafka/RabbitMQ;
- Elasticsearch;
- Keycloak or a simulated external identity provider;
- another primary database or object store.

Complexity is acceptable only when the system produces a requirement that justifies it.

## 5. Working model: ChatGPT, Codex, GitHub

The preferred division of labor is:

### ChatGPT — coordination and review

Use ChatGPT to:

- recover the current repository state;
- confirm the active milestone and next implementation slice;
- resolve design/scope questions;
- write or amend plans/ADRs when required;
- inspect diffs, PR state, CI results, and first causal failures;
- decide whether a change is acceptable to merge;
- maintain milestone/handoff documentation.

### Codex — substantive repository implementation

Use Codex as the preferred workspace for substantial multi-file implementation, refactoring, tests, frontend work, infrastructure, or automation.

A Codex task should be bounded by the committed active plan and a concrete implementation slice with explicit done conditions.

### Do not parallel-edit the same implementation scope

ChatGPT and Codex must not independently modify the same branch/slice at the same time.

For one implementation slice:

1. lock the exact base commit and scope;
2. give Codex the committed plan/constraints when it owns implementation;
3. let Codex implement and run available checks;
4. review the resulting GitHub diff and exact-head CI independently;
5. only then merge or request a narrow correction.

ChatGPT may directly perform small documentation, metadata, CI/PR operations, or narrowly scoped fixes. It should not duplicate a substantive Codex implementation just to produce a second competing version.

GitHub, not either model's narrative, remains the durable source of truth.

## 6. Change-size and PR discipline

Prefer reviewable vertical slices.

A slice should normally prove one coherent boundary, for example:

- schema/domain foundation;
- business services;
- auth/program REST boundary;
- applicant/reviewer REST boundary;
- SPA shell/auth;
- applicant UI;
- reviewer/admin UI;
- browser E2E/routing closeout.

Do not mix unrelated architecture, UI, infrastructure, and performance work into one PR.

Every substantive PR must:

- branch from the intended current base;
- preserve active milestone scope;
- include focused tests;
- keep relevant previous milestone tests green;
- pass required exact-head GitHub Actions before merge;
- verify post-merge `main` when the workflow runs there.

## 7. Evidence standard

Portfolio claims must be tied to something actually implemented or measured.

Acceptable evidence includes:

- committed code/migrations/configuration;
- integration/concurrency/E2E tests;
- exact-head CI;
- sanitized runtime commands/output;
- query plans and measurements;
- failure/recovery records.

Do not turn an architectural intention into a completed-experience claim before it has been implemented and verified.

Use synthetic users, organizations, applications, files, and workload data. Never use real personal/company data to make the project appear more realistic.


## 8. Portfolio evidence operating rule

The project is complete only when it produces explainable evidence, not when it accumulates technologies.

Use `docs/portfolio/PORTFOLIO_EVIDENCE_MAP.md` as the durable portfolio-evidence control plane. It records current problem candidates, evidence maturity, missing gates, rejected résumé-driven additions, and which items are allowed to become primary stories.

### Completion and portfolio-readiness are different

A milestone may be technically complete while producing no new primary portfolio story.

Examples:

- M7 may successfully install/verify observability but remain enabling infrastructure.
- M8 may prove that a hypothesized bottleneck is not material.
- M9 may optimize only one query even if several technologies are available.
- A technology such as Redis may remain absent because no measured requirement justifies it.

Do not manufacture a problem so that a planned technology can be used.

### Required evidence progression

For a problem-solving claim, prefer:

`assumption/context → observed problem → baseline → analysis → options → decision → change → comparable re-test → trade-off`

Correctness/concurrency/recovery claims may use invariant/failure evidence instead of latency improvements, but must still distinguish observed facts from assumptions.

Any candidate promoted beyond correctness-only evidence should receive a committed evidence card based on `docs/portfolio/EVIDENCE_CARD_TEMPLATE.md`.

### Technology-introduction gate

A new major technology outside the frozen architecture is rejected unless the active plan/ADR can answer:

1. what current requirement is not adequately handled;
2. what evidence shows it is material;
3. what simpler option was considered first;
4. what new operational/failure complexity is introduced;
5. how the same condition will be re-tested.

This prevents adding Redis, Kafka, Elasticsearch, Kubernetes, another datastore, or similar components merely for résumé breadth.

### Final story budget

M12 should normally select only **2–3 primary E5 stories**.

The current strongest candidates are tracked in the evidence map. Supporting implementation, certifications, infrastructure, UI work, and rejected alternatives remain useful interview context but do not all become résumé bullets.

### Milestone evidence update rule

When a milestone or experiment changes evidence maturity:

1. update the relevant Evidence Map row;
2. create/update an Evidence Card when the item moves beyond E2;
3. link retained code/test/CI/runtime/query-plan evidence;
4. record a negative result when a hypothesis did not become a material problem;
5. do not raise maturity based only on implementation intent.

## 9. Current milestone recovery rule

The current milestone and exact implementation checkpoint belong in the active plan, not in this evergreen document.

A new session must recover, in order:

1. `AGENTS.md`;
2. `README.md`;
3. this document;
4. `docs/WORKFLOW.md`;
5. accepted ADRs and relevant frozen M0 documents;
6. `docs/portfolio/PORTFOLIO_EVIDENCE_MAP.md`;
7. the current file under `docs/plans/active/`;
8. current `main`, open PRs, and exact-head/post-merge CI state.

If the repository cannot answer what has been completed and what the next slice is, repair the documentation before continuing implementation.
