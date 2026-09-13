# AI Project State — Fast Resume Checkpoint

Status: ACTIVE  
Last updated: 2026-09-13 UTC

This file is the short execution checkpoint for ChatGPT/Codex sessions. It is **not** an
architecture document, ADR, milestone plan, or evidence record.

## Resume protocol

At the start of a project-work session:

1. Read `AGENTS.md`.
2. Read this file.
3. Read the current active milestone plan under `docs/plans/active/`, when one exists.
4. Inspect only the exact repository files, PR, workflow run, or live command output
   relevant to the current task.
5. Expand to `docs/WORKFLOW.md`, frozen M0 documents, ADRs, or broader repository search
   only when the current task requires it.

Do not reconstruct completed milestones from chat history when the repository already
records them.

## Execution rule

Use **one turn = one logical, verifiable work result**.

For a failure:

1. lock the exact command/run/SHA;
2. identify the first meaningful causal failure;
3. make the smallest supported correction;
4. verify the same boundary again;
5. do not broaden scope unless the failure requires it.

## Tool split

- **GitHub/repository:** durable source of truth, code, plans, PRs, CI, committed evidence.
- **ChatGPT:** current-step coordination, root-cause analysis, small targeted fixes,
  PR/CI review, merge/post-merge verification.
- **Codex:** substantive multi-file implementation only when a bounded implementation
  slice exists.
- **Cloud Shell / ops-01:** live GCP/runtime execution.

## Current project checkpoint

Repository: `siamese-lang/application-review-platform`

M6 implementation/release base:

`9d5fda9871e479e05dc4641fccf7dea3145d2ad6`

Milestone state:

- M1 Business MVP — complete
- M2 Data Integrity — complete
- M3 Attachment — complete
- M4 Cloud Deployment — complete
- M5 Web/API & Product Surface — complete
- M6 Operations & Delivery — complete
- M7 Observability — next; implementation not started

M6 completed plan:

`docs/plans/completed/M6-operations-delivery.md`

M6 Phase 6 usability plan:

`docs/plans/completed/M6-phase6-korean-ui-usability.md`

## Current live environment

- frozen seven-role GCP runtime is running;
- WIF/IAP/OS Login release handoff is live;
- TLS public edge, PostgreSQL, Garage, Nginx, SOPS/age, and release activation are healthy;
- runtime OpenTofu plan: no changes, detailed exit code 0;
- owner-bootstrap OpenTofu plan: no changes;
- lifecycle decision: retain the seven-role runtime for immediate M7 work and re-evaluate
  retain/destroy at M7 closeout.

Final deployed M6 release:

- SHA: `9d5fda9871e479e05dc4641fccf7dea3145d2ad6`
- OCI digest: `sha256:13c3d117eef036c6987f00faf44e01b86845528c62bab1a3ea0914a234a103d4`
- post-merge publication run: `34737855198`
- exact-release handoff run: `34746439784`
- backend/frontend release state: current = `9d5fda9871e479e05dc4641fccf7dea3145d2ad6`,
  previous = `60a7efe40dd7f3d6f0c0f10396246c4da4148cc4`
- final HTTPS/API/Garage smoke: passed

Retained Phase 5 rollback evidence:

- Release A SHA: `53f5796235114481c62d9d178e395738f486ea3e`
- Release B SHA: `a26193598d0fbcb5a2f6d468739b36b7aef3f0aa`
- real schema-compatible B → A rollback: passed
- observed rollback elapsed time: `38,346 ms`
- database migration rollback: **not performed**
- post-rollback business/attachment smoke: passed
- Evidence Card maturity: **E5**

Evidence:

- `docs/operations/M6_PHASE4_RUNTIME_EVIDENCE.md`
- `docs/operations/M6_PHASE5_RELEASE_ROLLBACK_EVIDENCE.md`
- `docs/operations/M6_PHASE6_CLOSEOUT_EVIDENCE.md`
- `docs/portfolio/M6_IMMUTABLE_RELEASE_ROLLBACK_EVIDENCE.md`
- `docs/portfolio/PORTFOLIO_EVIDENCE_MAP.md`

## Immediate next work

Do **not** resume M6 implementation.

Next work is to create the bounded **M7 Observability active plan** from the frozen
architecture and evidence requirements before changing runtime configuration.

M7 is primarily enabling evidence infrastructure. It must make later M8–M10 workload,
performance, and failure questions measurable; merely installing
Prometheus/Loki/Tempo/Grafana/Alertmanager/Alloy is not a portfolio claim.

The existing seven-role runtime is intentionally retained for this immediate next
milestone. Do not recreate it or destroy it during planning.

## Do not revisit unless new evidence requires it

- application workflow design;
- React/Spring/Nginx boundary;
- PostgreSQL/Garage choice;
- M6 release/rollback design and completed drill;
- M6 Korean UI remediation;
- final M6 no-drift verification.

## Short resume prompt

A new chat normally needs only:

> @GitHub `siamese-lang/application-review-platform` 작업을 계속한다.  
> 먼저 `AGENTS.md`, `docs/AI_PROJECT_STATE.md`, 현재 active plan이 있으면 그것만 읽고 repository 실제 상태를 source of truth로 사용하라.  
> 완료된 milestone이나 관련 없는 구조를 재검토하지 마라.  
> 현재 state의 Immediate next work에서 첫 미완료 작업 하나만 처리하라.  
> 오류가 있으면 exact SHA/run/명령의 최초 causal failure만 확인하고 최소 수정 후 같은 경계를 재검증하라.
