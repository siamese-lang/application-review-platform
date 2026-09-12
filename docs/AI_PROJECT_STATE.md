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

Good units:

- identify one failed workflow/job and its first causal error;
- make one minimal repository fix and open/update its PR;
- verify one exact-head CI result;
- complete one bounded live-operation checkpoint;
- close one phase after its done conditions are met.

Avoid combining unrelated work such as root-cause analysis, architecture redesign, refactoring, deployment, evidence promotion, and the next milestone in one turn.

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

Current main at this checkpoint:

`4c143d9f90960c941f4bc0c1c679d55be3658fb0`

Current milestone:

- M6 Operations & Delivery — ACTIVE
- Phase 1 — complete
- Phase 2 — complete
- Phase 3 — complete
- Phase 4 — complete
- Phase 5 — active

Current live environment:

- frozen seven-role GCP runtime is running;
- WIF/IAP/OS Login handoff is live;
- TLS for the current edge IP is configured;
- PostgreSQL, Garage, Nginx, SOPS/age, and runtime prerequisites are configured;
- runtime and owner-bootstrap OpenTofu roots were verified no-drift before Phase 5 execution.

Recent concrete fixes:

- PR #46: add only the instance-scoped `ops-01` Compute Viewer permission required by live `gcloud compute ssh` guest-attribute host-key lookup; project-wide Compute Viewer remains forbidden.
- PR #47: restore PostgreSQL `DO $$ ... END $$;` quoting in the synthetic-user bootstrap and add regression coverage.

Phase 5 live progress:

- GitHub exact-release handoff succeeded after PR #46.
- Release A is staged and has been activated successfully.
- Release A SHA:
  `53f5796235114481c62d9d178e395738f486ea3e`
- Release A OCI digest:
  `sha256:0f3ec84718f001439b1cab365cfe8dc5f18246395f0dd0d3b71bb8d1398a49f9`
- Observed activation result: Ansible recap reported `failed=0` for `app-01` and `edge-01`; `deploy-release exit=0`.
- This activation result is a live checkpoint, not yet the completed M6 evidence claim.

## Immediate next work

Continue **only** Block B:

1. verify Flyway schema history through V5;
2. bootstrap synthetic REVIEWER/ADMIN/APPLICANT users;
3. run the Phase 5 HTTPS SPA/API/Garage business smoke;
4. stop at the first causal failure, or record Block B pass.

Do not yet start the rollback drill, evidence closeout, M7 work, or unrelated refactoring.

## Do not revisit unless new evidence requires it

- application workflow design;
- React/Spring/Nginx boundary;
- PostgreSQL/Garage choice;
- seven-role GCP topology;
- WIF trust model except for a concrete authorization failure;
- Phase 1–4 design decisions;
- runtime recreation/TLS bootstrap already completed for this M6 run.

## Short resume prompt

A new chat normally needs only:

> @GitHub `siamese-lang/application-review-platform` 작업을 계속한다.  
> 먼저 `AGENTS.md`, `docs/AI_PROJECT_STATE.md`, 현재 active plan만 읽고, repository 실제 상태를 source of truth로 사용하라.  
> 완료된 milestone이나 관련 없는 구조를 재검토하지 마라.  
> 현재 state의 Immediate next work에서 첫 미완료 작업 하나만 처리하라.  
> 오류가 있으면 exact SHA/run/명령의 최초 causal failure만 확인하고 최소 수정 후 같은 경계를 재검증하라.  
> 외부 GCP 실행이 필요한 지점에서는 필요한 명령을 한 논리 작업 단위로 묶어서 제시하고 멈춰라.
