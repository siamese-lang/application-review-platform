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
- M7 Observability — ACTIVE
- M7 Phase 1 repository observability foundation — complete
- M7 Phase 2 central observability stack and Alloy baseline — complete
- M7 Phase 3 source instrumentation and secure telemetry pipelines — NEXT

M6 completed plan:

`docs/plans/completed/M6-operations-delivery.md`

M6 Phase 6 usability plan:

`docs/plans/completed/M6-phase6-korean-ui-usability.md`

## Current live environment

Current live state is still the **seven-node M6 runtime**. M7 `obs-01` has not been
applied yet.

- frozen seven-role GCP runtime is running;
- WIF/IAP/OS Login release handoff is live;
- TLS public edge, PostgreSQL, Garage, Nginx, SOPS/age, and release activation are healthy;
- runtime OpenTofu plan: no changes, detailed exit code 0;
- owner-bootstrap OpenTofu plan: no changes;
- lifecycle decision: retain the seven-role runtime for immediate M7 work and re-evaluate
  retain/destroy at M7 closeout.

## M7 target runtime and Free Trial resource strategy

Source of truth:

- `docs/architecture/ADR-004-gcp-resource-placement.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/FREEZE_RECORD.md`
- `docs/workload/WORKLOAD.md`
- `docs/plans/active/M7-observability.md`

Do not reinterpret this from chat history.

After M7 live activation, the persistent Seoul runtime is intentionally **eight VMs**:

- `edge-01`
- `app-01`
- `db-01`
- `storage-01`
- `storage-02`
- `storage-03`
- `ops-01`
- `obs-01`

`obs-01` target:

- region/zone: `asia-northeast3-a`;
- private IP: `10.40.0.60`;
- machine type: `e2-standard-2`;
- boot: 20 GiB `pd-standard`;
- observability data: 40 GiB `pd-standard`;
- no public IP.

Why:

- M6 evidence recorded Seoul quota of 8 instances, 32 E2 CPUs, and 250 GiB SSD total;
- M7 deliberately consumes the eighth instance;
- `pd-standard` on `obs-01` avoids exceeding the recorded SSD quota;
- the user explicitly allows the $300/90-day Free Trial credit to be spent when it
  preserves useful architecture/measurement boundaries.

Future temporary resources must not cause the persistent Seoul topology to be collapsed:

- `loadgen-01`: cross-region by default, preferably `asia-northeast1` (Tokyo);
- `backup-01`: cross-region by default when introduced;
- temporary DR verification VMs: cross-region by default;
- `app-02`: only if measured scale-out evidence requires it; placement is decided by
  that experiment, not automatically moved cross-region.

For cross-region k6, compare runs from the same loadgen region and separate end-to-end
client/network latency from Nginx upstream, Spring/trace, and PostgreSQL server evidence.
Do not run k6 on `obs-01` or a measured business VM merely to bypass quota.

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

## Current active plan

`docs/plans/active/M7-observability.md`

## Public repository and M7 Phase 1 closeout

The repository is now **public**.

Public-transition verification:

- public-readiness secret/history audit: passed;
- no credential rotation or history rewrite required;
- repository ruleset `protect-main`: active;
- force-push/deletion blocked on the default branch;
- pull request required;
- strict required CI checks configured;
- PR #58 M7 Phase 1 merge:
  `dfeb5cab85698812294878bcf3a154d5d628967b`;
- PR #58 exact-head CI `34752303087`: SUCCESS;
- PR #59 browser-E2E locator correction merge:
  `3f7de55356e097793debf3f97e3480667d5bb6a5`;
- PR #59 exact-head CI `34752944074`: SUCCESS;
- final post-merge `main` CI `34753065713`: SUCCESS.

The public transition solved the private-repository GitHub Actions minute exhaustion
without replacing the established CI platform.

## M7 Phase 2 closeout

Phase 2 is complete on repository state ending at main
`fc10d4a78994d4fe8df403ff5dfe39c2f02dc9f5`.

Completed repository-side boundaries:

- pinned Prometheus, Loki, Tempo, Grafana, Alertmanager, and reusable Alloy configuration;
- Grafana datasource provisioning and the bounded four-dashboard set;
- conservative structural Prometheus alert rules;
- bounded retention plus CPU/memory limits for the central stack;
- upstream-supported config validation and repository contract checks;
- no plaintext application/DB/Garage runtime credentials;
- no live GCP apply and no public observability listener introduced.

The live environment is still the seven-node M6 runtime. `obs-01` is not live yet.

## M7 CI consolidation

The Phase 2 component CI has been consolidated into
`.github/workflows/m7-observability-ci.yml`.

Behavior after consolidation:

- `baseline-ci` remains separate and unchanged;
- the M7 workflow runs only for observability-related pull-request paths;
- changed-file detection runs only the affected Prometheus/Loki/Tempo/Grafana/Alertmanager/
  Alloy validation steps, while shared observability config changes validate all components;
- the existing component repository-contract scripts and pinned upstream validators are
  preserved;
- redundant Loki/Tempo/Grafana/Alertmanager/Alloy workflow files are removed;
- the M7 workflow no longer reruns on the post-merge `main` push.

The `protect-main` required status contexts do not depend on the removed component workflow
jobs; the required M7 infrastructure check remains provided by the existing baseline CI.

## Immediate next work

Proceed to **M7 Phase 3 — Source instrumentation and secure telemetry pipelines** from the
first incomplete work item in the active plan.

Keep Phase 3 implementation bounded: introduce source telemetry only where the active plan
requires it, preserve private/local management boundaries, and do not perform live GCP
activation until Phase 4.

Key constraints remain:

- preserve the existing seven-node live runtime until Phase 4 activation;
- no public Grafana/Actuator/telemetry exposure;
- no plaintext runtime secrets or body/authorization logging;
- preserve all M1–M6 behavior and release mechanics;
- no M8 workload or M9 optimization;
- follow ADR-004 for later cross-region temporary resources;
- use pinned versions, never floating `latest`.

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
