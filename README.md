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
- ADR-004: persistent Seoul runtime + temporary cross-region experiment/recovery placement accepted
- M5 Web/API & Product Surface: complete
- M5 completed plan: `docs/plans/completed/M5-web-api-product-surface.md`
- M5 final implementation PR #30 merged as `d8c34ebfa5a39cf253c5f9e1908d9a48cfa5bd88`; exact-head workflow `34614094018` and post-merge `main` workflow `34614462225` passed
- React SPA public/auth, applicant, reviewer, and admin workflows are implemented; real-stack Chromium E2E covers the applicant/reviewer business flow, and Nginx routing verification proves SPA fallback, fingerprinted-asset caching, and `/api` proxy isolation
- Legacy Thymeleaf presentation code is removed; Spring Boot owns the `/api/v1` application boundary while Nginx owns browser presentation routing
- M6 Operations & Delivery: complete
- M6 completed plan: `docs/plans/completed/M6-operations-delivery.md`
- M6 immutable release/rollback evidence: `docs/operations/M6_PHASE5_RELEASE_ROLLBACK_EVIDENCE.md`
- M6 Phase 6 closeout evidence: `docs/operations/M6_PHASE6_CLOSEOUT_EVIDENCE.md`
- M6 portfolio candidate: E5 in `docs/portfolio/M6_IMMUTABLE_RELEASE_ROLLBACK_EVIDENCE.md`
- Final deployed M6 release SHA: `9d5fda9871e479e05dc4641fccf7dea3145d2ad6`
- Final deployed M6 OCI digest: `sha256:13c3d117eef036c6987f00faf44e01b86845528c62bab1a3ea0914a234a103d4`
- Current implementation milestone: M7 Observability
- Active plan: `docs/plans/active/M7-observability.md`
- M7 Phase 1 repository observability foundation: complete
- Current M7 slice: Phase 2 central observability stack and Alloy baseline; no live GCP change yet
- Repository visibility: public; `protect-main` ruleset active

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

See `docs/architecture/ADR-001-web-api-spa.md` for the browser/API decision, `docs/architecture/ADR-002-account-lifecycle.md` for public registration and privileged-role provisioning, `docs/architecture/ADR-003-program-lifecycle.md` for program publication/intake and reviewer claim semantics, and `docs/architecture/ADR-004-gcp-resource-placement.md` for quota-aware runtime/experiment placement.

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
- M6 recreated and verified the same seven-role runtime. Final runtime and owner-bootstrap OpenTofu plans are no-drift.
- The current live runtime is still seven nodes; M7 targets an eight-node Seoul runtime by adding private `obs-01`.
- Resource placement follows `docs/architecture/ADR-004-gcp-resource-placement.md`: preserve the Seoul runtime and place later temporary load/backup/DR resources cross-region by default rather than collapsing roles for quota/cost reasons.
- Repository OpenTofu/Ansible plus sanitized M4/M6 evidence remain the reproducible record.

See `docs/operations/GCP_BASELINE.md` and `docs/operations/M4_RUNTIME_EVIDENCE.md`.

## Source of truth

Read `AGENTS.md` first. `docs/PROJECT_EXECUTION.md` defines the durable project purpose, evidence gates, DB/SQL requirement, and anti-drift rules. `docs/portfolio/PORTFOLIO_EVIDENCE_MAP.md` is the durable map of candidate problem-solving stories, current evidence maturity, rejected résumé-driven additions, and missing proof. The M0 documents under `docs/`, accepted ADRs, the current active plan, code/configuration, PRs, and exact-head CI together define project state.

`docs/WORKFLOW.md` defines how ChatGPT, Codex, GitHub, GitHub Actions, external documentation, and GCP/`ops-01` work together. New sessions should recover project state from the repository before relying on prior conversation context.

## Planned stack

Java 21, Spring Boot 4.1.x, Spring REST/MVC infrastructure, Spring Security, Spring Session JDBC, Spring Data JPA, Flyway, PostgreSQL, Garage, React, TypeScript, Vite, Nginx, Prometheus, Loki, Tempo, Grafana, Alertmanager, Grafana Alloy, pgBackRest, k6, OpenTofu, Ansible, GitHub Actions, GHCR, SOPS + age.

Thymeleaf migration presentation code was removed in M5; React/Vite behind Nginx is the supported browser presentation.

## Milestones

Completed milestones retain their original numbering:

M1 Business MVP → M2 Data Integrity → M3 Attachment → M4 Cloud Deployment

Future plan after ADR-001/ADR-002/ADR-003/ADR-004:

M5 Web/API & Product Surface → M6 Operations & Delivery → M7 Observability → M8 Workload → M9 Performance → M10 Reliability → M11 DR → M12 Portfolio
