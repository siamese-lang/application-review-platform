# AI Project State — Fast Resume Checkpoint

Status: ACTIVE  
Last updated: 2026-09-15 UTC

This file is the short execution checkpoint for ChatGPT/Codex sessions. It is not an
architecture document, ADR, milestone plan, or evidence record.

## Resume protocol

At the start of a project-work session:

1. Read `AGENTS.md`.
2. Read this file.
3. Read the current active milestone plan under `docs/plans/active/` when one exists.
4. Inspect only the exact repository files, PR, workflow run, or live output required for
   the current task.
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
- M8 Workload — **complete**
- M9 Performance — **ACTIVE**

Completed M8 plan:

`docs/plans/completed/M8-workload.md`

Current active plan:

`docs/plans/active/M9-performance.md`

M9 begins from measured SQL/plan evidence. Do not begin optimization from a predetermined solution.

Latest retained workload source baseline:

`d6c30508eed79fbc6dfc67de07ce0099817f3a60`

## M8 retained evidence

Primary evidence:

`docs/operations/M8_WORKLOAD_EVIDENCE.md`

Portfolio evidence card:

`docs/portfolio/M8_POSTGRESQL_QUERY_BOTTLENECK_EVIDENCE.md`

### W1 correctness smoke

- run `m8-w1-20260914T181710Z-faf46c4c`;
- dataset S / seed `20260914`;
- real HTTPS/session/CSRF boundary;
- all frozen workload families passed;
- correctness evidence only.

### W2 normal baseline

- run `m8-w2-20260914T203329Z-ac3d7657`;
- dataset M / seed `20260914`;
- 30 VU / 15 minutes;
- 26,864 business requests;
- frozen mix preserved;
- non-file success 100%;
- non-file p95 222.197 ms;
- Hikari pending 0;
- db-01 CPU average about 36.7%, max about 52.8%;
- reviewer queue result/count SQL means 100.136/67.933 ms.

W2 is the healthy normal-load baseline.

### W3 bounded peak

Final retained run:

- run `m8-w3-20260915T021822Z-d6c30508`;
- dataset M / seed `20260914`;
- 10 minutes;
- offered 100 business requests/s at frozen 40/15/10/20/10/5;
- hard 100-VU ceiling;
- completed iterations 17,336;
- dropped iterations 15,668, about 47.5% of scheduled iterations;
- completed business requests 29,814, about 49.7 requests/s;
- non-file success among executed requests 100%;
- non-file p95 2,067.479 ms;
- internal regression target FAIL;
- support-path error rate about 6.07%.

Correlated W3 telemetry:

- Hikari active average about 8.61, max 10;
- Hikari pending average about 39.52, max 54;
- db-01 CPU average about 90.94%, max about 99.98%;
- PostgreSQL deadlocks 0;
- edge-01 CPU average about 3.49%, max about 6.07%;
- private application probe remained 1;
- edge listen overflow/drop remained 0.

W3 query means:

- applicant list 215.726 ms;
- reviewer queue result 417.049 ms;
- reviewer queue count 305.405 ms.

Compared with W2, those means rose about 7.0x/4.2x/4.5x.

Diagnostic history retained separately:

- `docs/operations/M8_W3_ABORTED_DIAGNOSTIC.md`;
- `docs/operations/M8_W3_CLOSED_VU_SATURATION.md`.

W4 and higher stress were intentionally not executed because W3 already produced a stable,
material saturation signal and concrete SQL candidates.

## Current live environment

Retained Seoul runtime:

- edge-01
- app-01
- db-01
- storage-01
- storage-02
- storage-03
- ops-01
- obs-01

Retained `storage-03` overrides:

- machine: `e2-small`;
- boot disk: `pd-standard`.

Temporary M8/M9 load generator:

- `loadgen-01`;
- Tokyo `asia-northeast1-a`;
- private IP `10.50.0.10`;
- machine `e2-standard-2`;
- no public IP;
- retained intentionally through M9 for same-condition before/after workload measurement.

M8 final runtime OpenTofu plan, with `enable_loadgen=true` and retained overrides:

`No changes. Your infrastructure matches the configuration.`

M9 closeout owns the final loadgen lifecycle/destruction decision.

## M9 immediate next work

M9 Phase 1 is complete and Phase 2 intervention selection is complete.

First intervention:

- Flyway V7 index:
  `applications(status, updated_at, id) INCLUDE (reviewer_id)`;
- no JPQL change;
- no Hikari/VM/PostgreSQL/cache change;
- focused PostgreSQL integration test verifies the index contract.

Reason:

- simplifying the duplicated reviewer/status predicate improved the planner estimate somewhat
  but did not reduce sequential-scan/buffer work;
- the measured queue path still scanned the application table and processed 10,542
  qualifying rows before returning 20.

Continue **M9 Phase 3 — implement and verify the first intervention**.

Immediate next boundary:

1. review the V7 migration and focused test diff;
2. exact-head CI must pass;
3. merge only the index intervention;
4. deploy the exact reviewed release through the existing delivery path;
5. record Flyway migration/index-build behavior;
6. rerun the same reviewer result/count `EXPLAIN (ANALYZE, BUFFERS)` before W2/W3
   remeasurement.

No performance improvement claim exists yet. Evidence remains **E3**.

## Do not revisit unless new evidence requires it

- M1–M8 completed design/evidence;
- M6 release/rollback drill;
- M7 observability closeout;
- W1/W2/W3 workload harness history;
- closed-VU vs arrival-rate harness decision;
- React/Spring/Nginx boundary;
- PostgreSQL/Garage architecture choice.

## Short resume prompt

> @GitHub `siamese-lang/application-review-platform` 작업을 계속한다.  
> 먼저 `AGENTS.md`, `docs/AI_PROJECT_STATE.md`, 현재 active plan이 있으면 그것만 읽고
> repository 실제 상태를 source of truth로 사용하라.  
> M8은 완료되었으므로 재실행하거나 재설계하지 마라.  
> `docs/plans/active/M9-performance.md`의 첫 미완료 Phase 1 작업부터 진행하라.  
> reviewer queue result/count SQL을 1순위 후보로 삼되 solution을 미리 정하지 말고
> 실제 SQL + `EXPLAIN (ANALYZE, BUFFERS)` 증거부터 확보하라.
