# AI Project State — Fast Resume Checkpoint

Status: ACTIVE  
Last updated: 2026-09-12 UTC

This file is the short execution checkpoint for ChatGPT/Codex sessions. It is **not** an architecture document, ADR, milestone plan, or evidence record. Its purpose is to prevent every turn from rebuilding the whole project context.

## Resume protocol

At the start of a project-work session:

1. Read `AGENTS.md`.
2. Read this file.
3. Read the current active milestone plan under `docs/plans/active/`.
4. Inspect only the exact repository files, PR, workflow run, or live command output relevant to the current task.
5. Expand to `docs/WORKFLOW.md`, frozen M0 documents, ADRs, or broader repository search only when:
   - the current task changes an architectural boundary;
   - sources conflict;
   - the active plan does not answer the scope question;
   - the first causal failure cannot be explained from the bounded context.

Do **not** rescan the entire repository or reconstruct completed milestones on every turn.

## Execution rule

Use **one turn = one logical, verifiable work result**.

For a failure:

1. lock the exact command/run/SHA;
2. identify the first meaningful causal failure;
3. make the smallest supported correction;
4. verify the same boundary again;
5. do not broaden scope unless the failure requires it.

If the cause is already clear, do not perform a fresh architecture review.

## Tool split

- **GitHub/repository:** durable source of truth, code, plans, PRs, CI, committed evidence.
- **ChatGPT:** current-step coordination, root-cause analysis, small targeted fixes, PR/CI review, merge/post-merge verification.
- **Codex:** substantive multi-file implementation only when a bounded implementation slice exists.
- **Cloud Shell / ops-01:** live GCP/runtime execution. Stop and return to repository work only when a concrete live defect requires code/configuration change.

Do not invoke Codex merely because a live command failed when the root cause is already a small targeted repository/configuration defect.

## Current project checkpoint

Repository: `siamese-lang/application-review-platform`

Current `main` at this checkpoint:

`a26193598d0fbcb5a2f6d468739b36b7aef3f0aa`

Current milestone:

- M6 Operations & Delivery — ACTIVE
- Phase 1 — complete
- Phase 2 — complete
- Phase 3 — complete
- Phase 4 — complete
- Phase 5 — complete
- Phase 6 — active

Current live environment:

- frozen seven-role GCP runtime is running;
- WIF/IAP/OS Login handoff is live;
- TLS for the edge public IP is configured;
- PostgreSQL, Garage, Nginx, SOPS/age, and runtime prerequisites are configured;
- final intended Release B is active on both backend and frontend.

Final intended release:

- SHA: `a26193598d0fbcb5a2f6d468739b36b7aef3f0aa`
- OCI digest: `sha256:63716c0ff1b679ef2293fe1be47183828c87f323d13d2842bb8e8e84d280345c`
- exact-release handoff run: `34695033956`

Retained rollback target:

- Release A SHA: `53f5796235114481c62d9d178e395738f486ea3e`
- OCI digest: `sha256:0f3ec84718f001439b1cab365cfe8dc5f18246395f0dd0d3b71bb8d1398a49f9`

Phase 5 verified:

- Flyway V1–V5 successful; failed migration count 0;
- synthetic APPLICANT/REVIEWER/ADMIN identities bootstrapped without exposing credentials;
- live HTTPS SPA/API/Garage business smoke passed;
- Release B activated with backend/frontend `current=B`, `previous=A`;
- schema-compatible B → A rollback succeeded;
- observed rollback elapsed time: `38,346 ms`;
- database migration rollback: **not performed**;
- full HTTPS/API/Garage smoke passed after rollback;
- Release B was restored and the final full smoke passed;
- final backend/frontend state is `current=B`, `previous=A`;
- sanitized evidence: `docs/operations/M6_PHASE5_RELEASE_ROLLBACK_EVIDENCE.md`;
- Evidence Card: `docs/portfolio/M6_IMMUTABLE_RELEASE_ROLLBACK_EVIDENCE.md`;
- Portfolio Evidence Map candidate maturity: E3.

Recent concrete fix:

- PR #49 corrected the synthetic-user PostgreSQL anonymous-block delimiter regression to exact `DO $$ ... END $$;` and added regression coverage.

## Immediate next work

Continue **only Phase 6 closeout**, in this order:

1. manually inspect the deployed HTTPS SPA pages required by the active plan;
2. run final owner-bootstrap and runtime OpenTofu plans and verify no drift;
3. explicitly choose and record runtime retain/destroy disposition;
4. finalize M6 evidence maturity and closeout docs;
5. move the M6 plan to completed, update README/state, require final exact-head CI, merge, and verify post-merge `main`.

Do not start M7 observability implementation yet.

## Do not revisit unless new evidence requires it

- application workflow design;
- React/Spring/Nginx boundary;
- PostgreSQL/Garage choice;
- seven-role GCP topology;
- WIF trust model except for a concrete authorization failure;
- Phase 1–5 design decisions;
- Release A/B deployment and rollback drill already completed.

## Short resume prompt

A new chat normally needs only:

> @GitHub `siamese-lang/application-review-platform` 작업을 계속한다.  
> 먼저 `AGENTS.md`, `docs/AI_PROJECT_STATE.md`, 현재 active plan만 읽고, repository 실제 상태를 source of truth로 사용하라.  
> 완료된 milestone이나 관련 없는 구조를 재검토하지 마라.  
> 현재 state의 Immediate next work에서 첫 미완료 작업 하나만 처리하라.  
> 오류가 있으면 exact SHA/run/명령의 최초 causal failure만 확인하고 최소 수정 후 같은 경계를 재검증하라.  
> 외부 GCP 실행이 필요한 지점에서는 필요한 명령을 한 논리 작업 단위로 묶어서 제시하고 멈춰라.
