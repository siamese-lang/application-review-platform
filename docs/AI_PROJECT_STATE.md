# AI Project State — Fast Resume Checkpoint

Status: ACTIVE  
Last updated: 2026-09-14 UTC

This file is the short execution checkpoint for ChatGPT/Codex sessions. It is not an
architecture document, ADR, milestone plan, or evidence record.

## Resume protocol

At the start of a project-work session:

1. Read `AGENTS.md`.
2. Read this file.
3. Read the current active milestone plan under `docs/plans/active/`, when one exists.
4. Inspect only the exact repository files, PR, workflow run, or live command output
   relevant to the current task.
5. Expand context only when the current task requires it.

Use current GitHub/repository state over chat history.

## Current project checkpoint

Repository: `siamese-lang/application-review-platform`

Milestones:

- M1 Business MVP — complete
- M2 Data Integrity — complete
- M3 Attachment — complete
- M4 Cloud Deployment — complete
- M5 Web/API & Product Surface — complete
- M6 Operations & Delivery — complete
- M7 Observability — complete
- M8 Workload — next

M7 completed plan:

`docs/plans/completed/M7-observability.md`

M7 closeout evidence:

`docs/operations/M7_OBSERVABILITY_EVIDENCE.md`

Portfolio maturity:

- M6 immutable release/rollback — E5 primary candidate;
- M7 observability — E2 enabling infrastructure.

## Current live environment

The verified runtime is intentionally retained for immediate M8 work.

Persistent Seoul runtime:

- `edge-01`
- `app-01`
- `db-01`
- `storage-01`
- `storage-02`
- `storage-03`
- `ops-01`
- `obs-01`

`obs-01`:

- private IP `10.40.0.60`;
- no public IP;
- Prometheus, Loki, Tempo, Grafana, Alertmanager;
- node-local telemetry forwarded through Alloy.

Final M7 runtime OpenTofu plan: **no changes**.

Retained capacity workaround:

- `storage-03` machine type: `e2-small`;
- `storage-03` boot disk: `pd-standard`.

Lifecycle decision: **retain the eight-node runtime for immediate M8 workload/baseline
work**. Re-evaluate cost/lifecycle at M8 closeout.

## Final M7 verification boundary

Final verification source revision:

`cea4ca09d05efd89bcb9227c866d841968c08547`

Verified live:

- required host/source metrics and application health probe;
- Spring request/JVM metrics;
- PostgreSQL metrics;
- distinct Garage metrics for all three storage nodes;
- Nginx/application/PostgreSQL/Garage logs in Loki;
- application request ID + trace/span log correlation;
- a real application trace in Tempo;
- Grafana Prometheus/Loki/Tempo datasource health and four provisioned dashboards with
  live telemetry;
- Prometheus alert → Alertmanager delivery → recovery clear;
- full HTTPS/API/Garage business smoke while the central observability stack was down;
- Prometheus/Loki telemetry resumption after restoration;
- final runtime OpenTofu no-drift.

Do not rerun M7 verification unless new evidence requires it.

## M7 live corrections retained in main

Live activation/verification produced bounded fixes, including:

- Grafana secret-schema completion;
- executable Alloy installation;
- private application health probe;
- duplicate OTLP metrics export removal;
- PostgreSQL log-read permission correction;
- Loki private query-path/ring addressing correction;
- bounded per-request application correlation logging.

Current main at M7 verification:

`cea4ca09d05efd89bcb9227c866d841968c08547`

## Immediate next work

Do **not** start M9 optimization or M10 fault experiments.

The next milestone is **M8 Workload**. No active M8 plan exists yet.

First incomplete repository task after the M7 closeout PR is merged:

1. read `docs/workload/WORKLOAD.md`, `docs/PROJECT_EXECUTION.md`, and the completed M7
   evidence;
2. create a bounded M8 active plan for representative workload generation and baseline
   measurement;
3. preserve the M7 observability runtime as the measurement substrate;
4. use a cross-region `loadgen-01` by default per ADR-004 rather than consuming
   `obs-01` or a business VM;
5. define repeatable scenarios/seeds and measurement outputs before implementation;
6. do not choose a performance fix in advance.

M8 must create representative conditions and baselines. It does not own optimization.

## Do not revisit unless new evidence requires it

- M1–M7 completed milestone design;
- React/Spring/Nginx product boundary;
- PostgreSQL/Garage product choice;
- M6 release/rollback design and drill;
- M7 Loki root-cause history;
- completed M7 metrics/logs/traces/dashboard/alert/isolation verification.

## Short resume prompt

> @GitHub `siamese-lang/application-review-platform` 작업을 계속한다.  
> 먼저 `AGENTS.md`, `docs/AI_PROJECT_STATE.md`, 현재 active plan이 있으면 그것만 읽고
> repository 실제 상태를 source of truth로 사용하라.  
> 완료된 milestone은 재검토하지 마라.  
> 현재 state의 Immediate next work에서 첫 미완료 작업 하나만 처리하라.
