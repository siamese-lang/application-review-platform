# Application Review Platform

지원사업 신청·심사 업무 흐름을 구현하고, 브라우저/API 경계부터 GCP IaaS 배포·관측·성능·장애·백업·복구까지 단계적으로 검증하는 개인 프로젝트입니다.

## Current status

- M0 design baseline: frozen, with accepted ADR amendments
- P0-A tool onboarding: complete
- P0-B repository bootstrap: complete
- P0-C GCP readiness: complete
- M1 Business MVP: complete
- M2 Data Integrity: complete
- M3 Attachment: complete
- M4 Cloud Deployment: complete
- M4 completed plan: `docs/plans/completed/M4-cloud-deployment.md`
- M4 runtime evidence: `docs/operations/M4_RUNTIME_EVIDENCE.md`
- M4 GCP runtime: verified and intentionally destroyed after evidence capture to control cost
- ADR-001: REST API + React SPA browser boundary accepted
- ADR-002: applicant self-registration + controlled reviewer/admin provisioning accepted
- ADR-003: admin program publication + derived intake window + generalized audit subjects accepted
- Current implementation milestone: M5 Web/API & Product Surface
- M5 pre-implementation architecture review: complete; ADR-001 through ADR-003 form the implementation baseline
- Active plan: `docs/plans/active/M5-web-api-product-surface.md`
- M5 implementation checkpoint: the current REST surface plus public/auth, applicant, reviewer, and admin React SPA workflows are implemented; real-stack Chromium E2E exercises the applicant/reviewer business flow against Spring Boot, PostgreSQL, Garage, Spring Session, CSRF, and the Vite `/api` proxy
- Next M5 slice: validate the Nginx SPA/API routing contract, remove or narrowly justify obsolete Thymeleaf presentation paths, then perform final M5 verification

This project is **production-like**, not a claim of real production operation. All users, organizations, applications, documents, workloads, and measurements are synthetic unless explicitly recorded otherwise.

## Current target architecture

```text
Browser
  │ HTTPS
  ▼
edge-01: Nginx
  ├─ /, /assets/** → React + TypeScript + Vite static release
  └─ /api/v1/**    → app-01: Spring Boot REST API
                          ├─ PostgreSQL
                          └─ Garage
```

The production browser/API path is same-origin through Nginx. Spring Security session authentication, Spring Session JDBC, CSRF protection, domain/service authorization, Flyway, PostgreSQL, Garage, and the split-role GCP IaaS boundary remain part of the architecture.

See `docs/architecture/ADR-001-web-api-spa.md` for the browser/API decision, `docs/architecture/ADR-002-account-lifecycle.md` for public registration and privileged-role provisioning, and `docs/architecture/ADR-003-program-lifecycle.md` for program publication/intake and reviewer claim semantics.

## Product workflow

Public entry path:

`program discovery → applicant registration/login → private application workflow`

Core application state flow:

`DRAFT → SUBMITTED → IN_REVIEW → NEEDS_REVISION → SUBMITTED` or `IN_REVIEW → APPROVED/REJECTED`

Roles:

- `APPLICANT`: self-register, browse programs, prepare/edit own applications, manage attachments, submit/resubmit, track status/results
- `REVIEWER`: controlled bootstrap/operations provisioning; work a review queue, claim submitted work on review start, inspect applications/evidence, request revision, approve/reject
- `ADMIN`: controlled bootstrap/operations provisioning; create/edit/publish support programs and inspect users, applications, histories, audits, and workflow counts

M5 adds the minimum structured user/program/application fields, program publication/intake rules, generalized audit subjects, and business UI required to make these workflows recognizable as a support-program application/review system rather than a generic CRUD interface.

## Identity claim boundary

M5 implements a real application-level registration/session/authorization boundary but uses synthetic identities only. It does not claim external identity proofing, email verification, password-reset delivery, MFA, SSO/OIDC, or reviewer invitation delivery.

Public registration always creates `APPLICANT`; browser clients cannot self-assign `REVIEWER` or `ADMIN`.

## GCP lifecycle

- Project ID: `application-review-platform`
- Primary region: `asia-northeast3`
- Primary zone: `asia-northeast3-a`
- M4 proved the seven-role IaaS topology with HTTPS and end-to-end business/attachment smoke.
- The live M4 runtime was destroyed after verification/merge to stop unnecessary trial-credit consumption.
- Repository OpenTofu/Ansible and sanitized M4 evidence remain the reproducible record; later milestones re-provision infrastructure only when required.

See `docs/operations/GCP_BASELINE.md` and `docs/operations/M4_RUNTIME_EVIDENCE.md`.

## Source of truth

Read `AGENTS.md` first. `docs/PROJECT_EXECUTION.md` defines the durable project purpose, portfolio evidence goals, DB/SQL evidence requirement, and anti-drift working rules. The M0 documents under `docs/`, accepted ADRs, the current active plan, code/configuration, PRs, and exact-head CI together define project state.

`docs/WORKFLOW.md` defines how ChatGPT, Codex, GitHub, GitHub Actions, external documentation, and GCP/`ops-01` work together. New sessions should recover project state from the repository before relying on prior conversation context.

## Planned stack

Java 21, Spring Boot 4.1.x, Spring REST/MVC infrastructure, Spring Security, Spring Session JDBC, Spring Data JPA, Flyway, PostgreSQL, Garage, React, TypeScript, Vite, Nginx, Prometheus, Loki, Tempo, Grafana, Alertmanager, Grafana Alloy, pgBackRest, k6, OpenTofu, Ansible, GitHub Actions, GHCR, SOPS + age.

Thymeleaf is migration-only after ADR-001 and is not the intended final browser presentation.

## Milestones

Completed milestones retain their original numbering:

M1 Business MVP → M2 Data Integrity → M3 Attachment → M4 Cloud Deployment

Future plan after ADR-001/ADR-002/ADR-003:

M5 Web/API & Product Surface → M6 Operations & Delivery → M7 Observability → M8 Workload → M9 Performance → M10 Reliability → M11 DR → M12 Portfolio
