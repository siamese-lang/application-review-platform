# AI Project State — Fast Resume Checkpoint

Status: ACTIVE  
Last updated: 2026-09-14 UTC

This file is the short execution checkpoint for ChatGPT/Codex sessions. It is not an
architecture document, ADR, milestone plan, or evidence record.

## Resume protocol

At the start of a project-work session:

1. Read `AGENTS.md`.
2. Read this file.
3. Read the current active milestone plan under `docs/plans/active/`.
4. Inspect only the exact repository files, PR, workflow run, or live output required for
   the current task.
5. Expand context only when the current task requires it.

Use current GitHub/repository state over chat history.

## Current project checkpoint

Repository: `siamese-lang/application-review-platform`

Current milestone:

- M1 Business MVP — complete
- M2 Data Integrity — complete
- M3 Attachment — complete
- M4 Cloud Deployment — complete
- M5 Web/API & Product Surface — complete
- M6 Operations & Delivery — complete
- M7 Observability — complete
- M8 Workload — **ACTIVE**

Current active plan:

`docs/plans/active/M8-workload.md`

Current verified main:

`b9bfff92ded572eefcdf4281d0a506a021392f72`

M8 Phase 1 repository foundation is complete.

Post-merge `main` baseline CI:

- run `34862295776`;
- status: completed;
- conclusion: SUCCESS.

## Current live environment

The verified eight-node Seoul runtime remains retained for M8:

- `edge-01`
- `app-01`
- `db-01`
- `storage-01`
- `storage-02`
- `storage-03`
- `ops-01`
- `obs-01`

M7 observability is the measurement substrate. Do not rerun its completed closeout checks
without new evidence.

Final M7 runtime OpenTofu plan: no changes.

Retained `storage-03` overrides:

- machine: `e2-small`;
- boot disk: `pd-standard`.

## M8 fixed boundaries

M8 creates representative conditions and baseline measurements. It does **not** optimize.

Frozen workload baseline:

- S: about 10k applications;
- M: about 100k applications + 400k history rows;
- L: about 500k applications + 2M history rows, later only if evidence requires it;
- normal baseline: about 30 VU for 15 minutes on M;
- bounded peak: about 100 VU for 10–15 minutes after normal baseline is healthy;
- stress progression continues only as evidence requires.

Initial API mix remains:

- list/detail 40%;
- create/save 15%;
- submit/resubmit 10%;
- reviewer queue/detail 20%;
- review actions 10%;
- attachments 5%.

Protected workloads must use the real session and CSRF boundary.

Per ADR-004, k6 runs from a separate temporary `loadgen-01`, defaulting to Tokyo
(`asia-northeast1`) when live quota/capacity permits. Do not run k6 on `obs-01` or any
measured business VM.

Cross-region k6 latency must be interpreted separately from Nginx upstream, Spring,
PostgreSQL, Garage, and host telemetry.

## Evidence rule

Every retained workload run must record:

- exact release/source identity;
- dataset size/seed;
- workload/scenario version;
- loadgen region/machine;
- VU profile/duration;
- think-time/attachment settings;
- runtime identity;
- timestamps.

M8 may identify candidate bottlenecks but must not:

- add speculative indexes;
- tune JVM/PostgreSQL merely to improve the baseline;
- add Redis/cache/queue;
- change business nodes for performance;
- begin M9 optimization.

A negative finding is valid evidence.

## Immediate next work

Proceed to **M8 Phase 2 — Deterministic synthetic dataset tooling** only.

Current implementation slice:

1. generate S/M/L database-scale fixture bundles from a fixed seed;
2. preserve the current Flyway schema and allowed application state-transition paths;
3. keep legacy `title/content` synchronized with M5 structured application fields;
4. provide guarded M8-namespace reset/load and verification SQL;
5. verify byte-identical regeneration and referential/state/history/version invariants in CI;
6. verify the generator field pattern through the real Spring application API integration boundary;
7. do not load dataset M into the live runtime yet;
8. do not create `loadgen-01` yet;
9. do not run W1/W2 or performance tuning.

After Phase 2 exact-head and post-merge CI pass, proceed to Phase 3 live quota/plan review and
dataset/loadgen preparation.

## Do not revisit unless new evidence requires it

- M1–M7 completed design/evidence;
- M6 release/rollback drill;
- M7 Loki root-cause history;
- completed M7 signal/dashboard/alert/isolation verification;
- React/Spring/Nginx boundary;
- PostgreSQL/Garage choice.

## Short resume prompt

> @GitHub `siamese-lang/application-review-platform` 작업을 계속한다.  
> 먼저 `AGENTS.md`, `docs/AI_PROJECT_STATE.md`, 현재 active plan만 읽고 repository
> 실제 상태를 source of truth로 사용하라.  
> 완료된 milestone을 재검토하지 마라.  
> M8 active plan의 첫 미완료 Phase 2 작업부터 진행하라.  
> M9 최적화나 speculative tuning을 M8로 끌어오지 마라.
