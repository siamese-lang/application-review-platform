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

`5de92b5aef5dda744d90c7694a3f667dac1b1d2f`

M8 Phase 1, Phase 2, and Phase 3 are complete. Phase 4 is active.

W1 and the valid W2 normal baseline/telemetry correlation are complete.

W3 evidence now has two diagnostic checkpoints:

- the first 100-VU attempt aborted after about 30 seconds because one support-path timeout
  globally aborted the harness; this was retained as diagnostic evidence only;
- the hardened 100 closed-VU / 10-minute run completed and exposed sustained DB/pool
  saturation, but its delivered business mix diverged materially under the closed-VU model.

The immediate implementation boundary is to preserve the same dataset/security/runtime
conditions while changing only W3 load generation to independent constant-arrival-rate
scenarios. The offered business rate remains 100 req/s at the frozen 40/15/10/20/10/5 mix
with a hard 100-VU ceiling. Capacity shortfall must surface as dropped iterations.

Latest verified post-merge `main` baseline CI before this W3 arrival-rate implementation branch:

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

Continue **M8 Phase 4 — W3 bounded peak**.

Do not repeat W1 or W2.

Retained W2 baseline:

- 30 VU / 15 minutes;
- 26,864 business requests;
- frozen mix preserved;
- non-file p95 222.197 ms;
- Hikari pending 0;
- db-01 CPU average about 36.7%, max about 52.8%.

Closed-VU W3 saturation diagnostic:

- run ID `m8-w3-20260915T014105Z-5de92b5a`;
- 100 VU / 10 minutes completed;
- non-file p95 1,991.346 ms;
- support error rate 7.8108%;
- Hikari pending average about 36.18, max 55;
- db-01 CPU average about 89.47%, max about 99.98%;
- application probe stayed healthy and edge saturation signals stayed absent;
- delivered mix diverged to 55.81/1.34/12.93/15.91/12.99/1.02 because slow closed-VU
  scenarios completed fewer iterations.

Immediate next slice:

1. review and merge the W3 constant-arrival-rate harness;
2. run dataset M for 10 minutes with offered 100 business req/s at
   40/15/10/20/10/5 and a hard 100-VU ceiling;
3. retain dropped iterations, support failures, client latency, pg_stat_statements, and M7
   telemetry;
4. decide from that result whether W4 adds material evidence;
5. do not optimize, resize, add indexes/cache/queue, or begin M9 yet.

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
