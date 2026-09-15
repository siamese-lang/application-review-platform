# AI Project State — Fast Resume Checkpoint

Status: ACTIVE  
Last updated: 2026-09-15 UTC

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

`ac3d7657f533f70126d12773c8b27f2c5b40b38e`

M8 Phase 1, Phase 2, and Phase 3 are complete. Phase 4 is active; W1 and the valid W2 client/database baseline are complete, with server-side telemetry correlation next.

Latest verified post-merge `main` baseline CI before this W2 implementation branch:

- run `34879613628`;
- status: completed;
- conclusion: SUCCESS.

Baseline CI now uses repository-owned affected-path job gating. Full regression remains
available through `workflow_dispatch`; unrelated milestone jobs should not block a focused
M8 workload-tooling change.

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

Temporary M8 load generator live checkpoint:

- `loadgen-01` exists in `asia-northeast1-a` (Tokyo);
- machine: `e2-standard-2`;
- private IP: `10.50.0.10`;
- public access configuration: absent;
- reviewed OpenTofu delta applied: `4 added, 0 changed, 0 destroyed`;
- persistent deployment `inventory` remains the same eight Seoul nodes;
- `ssh_inventory` additionally contains `loadgen-01`;
- repository-owned Ansible configuration completed on `loadgen-01`;
- pinned k6 metadata, package download checksum, installed version, and final assertion passed;
- loadgen play recap: `ok=8 changed=2 unreachable=0 failed=0`;
- deterministic dataset M seed `20260914` was loaded and verified live;
- manifest SHA-256:
  `9e174ead7c9ae7b77d5adc18c93e336b4cac5e30b5962bf47c31de4f42bea696`;
- verified counts: 12 programs, 1,048 users, 100,000 applications,
  399,990 histories, and 499,990 audits;
- deployed M8 API verification passed through real HTTPS/session/CSRF;
- pre-workload telemetry health passed with `probe_success=1`, Spring HTTP telemetry
  present, and `pg_up=1`.

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

Continue **M8 Phase 4 — W2 mixed normal baseline**.

W1 is complete and must not be repeated absent new evidence.

Verified W1:

- run ID `m8-w1-20260914T181710Z-faf46c4c`;
- dataset S / seed `20260914`;
- source `faf46c4c8256c9921a7aa6da37902b2d3dc53dbf`;
- backend release `cea4ca09d05efd89bcb9227c866d841968c08547`;
- frontend release `549511b0a8af9582125e89aaa2bde7fc4bffcd6d`;
- all frozen workload families passed through the real HTTPS/session/CSRF boundary;
- W1 timing is not performance evidence.

Verified W2:

- run ID `m8-w2-20260914T203329Z-ac3d7657`;
- source `ac3d7657f533f70126d12773c8b27f2c5b40b38e`;
- dataset M / seed `20260914`;
- 30 VU / 15 minutes;
- 26,864 business requests;
- observed mix 40.02/14.98/9.98/20.00/10.01/5.00;
- non-file success 100.0000%;
- non-file p95 222.197 ms;
- internal regression target PASS;
- reviewer queue/detail client p95 329.024 ms and the corresponding queue result/count SQL
  dominate the retained `pg_stat_statements` execution-cost snapshot.

Immediate next slice:

1. correlate the valid W2 run with existing M7 edge/application/JVM/PostgreSQL/Garage/host telemetry;
2. retain only sanitized server-side evidence needed to interpret the W2 client/database result;
3. decide from evidence whether W3 or a targeted W4 is useful;
4. do not optimize, resize, add indexes/cache/queue, or begin M9 yet.

Do not optimize, resize business nodes, add indexes/cache/queue, or begin M9 during W2.

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
> M8 active plan의 첫 미완료 Phase 4 작업부터 진행하라.  
> M9 최적화나 speculative tuning을 M8로 끌어오지 마라.
