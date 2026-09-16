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
- M9 Performance — **complete**
- M10 Reliability — **ACTIVE**

Completed M8 plan:

`docs/plans/completed/M8-workload.md`

Completed M9 plan:

`docs/plans/completed/M9-performance.md`

Current active plan:

`docs/plans/active/M10-reliability.md`

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

M8/M9 temporary load generator lifecycle:

- `loadgen-01` and its Tokyo subnet/router/NAT were removed at M9 closeout;
- reviewed destroy plan: exactly four delete actions;
- apply: 0 added, 0 changed, 4 destroyed;
- final `enable_loadgen=false` OpenTofu plan: no changes.

Persistent Seoul runtime remains unchanged with the retained `storage-03` overrides.

## M9 closeout

M9 Performance is complete.

Completed plan:

`docs/plans/completed/M9-performance.md`

Revalidated release:

`d90eb558bdb6317d49b0a7ce82148ddeb4b5babf`

Retained result:

- reviewer queue result/count bottleneck diagnosed with exact SQL and
  `EXPLAIN (ANALYZE, BUFFERS)`;
- predicate-only simplification rejected after measurement;
- one Flyway-managed index implemented:
  `applications(status, updated_at, id) INCLUDE (reviewer_id)`;
- W2 and W3 repeated under equivalent conditions;
- W3 non-file p95: 2,067.479 ms → 80.909 ms;
- W3 reviewer result/count means:
  417.049/305.405 ms → 0.645/9.497 ms;
- W3 db-01 CPU average: about 90.94% → 37.113%;
- W3 Hikari pending average: about 39.52 → 1.256;
- completed business requests: 29,814 → 44,097;
- project regression target: FAIL → PASS;
- no second database intervention justified;
- PostgreSQL query-bottleneck evidence: **E4**.

Measurement caveat:

- W3 after-run non-file success: 99.2652%;
- edge window showed no 5xx and no >=55s Nginx request;
- exact transient client/transport root cause is not claimed.

Runtime closeout:

- M9 retained-runtime plan before teardown: no drift;
- temporary Tokyo loadgen + subnet/router/NAT: removed;
- final `enable_loadgen=false` plan: no drift;
- persistent Seoul runtime retained.

## M10 immediate next work

M10 Reliability is ACTIVE.

Active plan:

`docs/plans/active/M10-reliability.md`

Fixed scenario scope:

- R1 application process failure;
- R2 PostgreSQL failure during normal synthetic workload;
- R3 Garage single-node failure;
- R4 bad deployment/rollback is already satisfied by M6 evidence;
- R5 logical corruption/PITR remains M11 scope.

Current phase:

**Phase 3 — R2 PostgreSQL outage during normal workload**

Immediate next boundary:

1. retain R1 as complete:
   - run `m10-r1-20260916T032112Z-c6847aa8`;
   - systemd restart observed after about 1.361 s;
   - fault → public API recovery about 22.988 s;
   - persisted session recovered without re-login;
   - static edge remained available;
   - PostgreSQL/Garage remained healthy;
   - post-recovery business smoke and DB invariants PASS;
2. keep temporary Tokyo `loadgen-01` while R2/R3 remain active;
3. inspect db-01 live PostgreSQL service/cluster and exporter state before any R2 fault;
4. implement/review the bounded R2 runner against the confirmed live service boundary;
5. execute one PostgreSQL outage under normal synthetic workload and restore it before R3;
6. do not add PostgreSQL failover architecture merely because the expected single-primary
   outage causes service unavailability.

No HA architecture change is authorized in advance.

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
> 먼저 `AGENTS.md`, `docs/AI_PROJECT_STATE.md`, `docs/plans/active/M10-reliability.md`
> 를 읽고 repository 실제 상태를 source of truth로 사용하라.  
> M1–M9은 완료되었으므로 재설계하거나 재실행하지 마라.  
> M10 Reliability Phase 1과 Phase 2 R1은 완료되었다. 현재 Phase 3 R2 PostgreSQL
> outage를 진행하되, fault 전에 db-01의 실제 PostgreSQL service/cluster/exporter 상태를
> 먼저 확인하라.  
> R1 app failure, R2 PostgreSQL failure, R3 Garage node failure만 초기 고정 범위로
> 수행하고 R4는 M6 evidence를 재사용하며 R5/PITR은 M11로 남겨라.
