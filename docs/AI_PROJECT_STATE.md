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

`d4dcdc0ec0ce7b769907cf42f789aab70b0ac745`

M8 Phase 1 and Phase 2 are complete. Phase 3 is active.

Post-merge `main` baseline CI:

- run `34870900830`;
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
- dataset M live generation/reset/load has **not yet run**.

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

Continue **M8 Phase 3 — Live loadgen and dataset M preparation**.

Completed Phase 3 gates:

1. trusted SSH inventory compatibility merged;
2. read-only Tokyo preflight passed;
3. project quota showed `CPUS_ALL_REGIONS limit=12 / usage=9`;
4. exact OpenTofu plan reviewed as `4 to add, 0 to change, 0 to destroy`;
5. that saved plan was applied;
6. `loadgen-01` is RUNNING at `10.50.0.10` with no public access configuration;
7. repository-owned loadgen configuration completed with pinned k6 verification and `failed=0`.

Immediate next slice:

1. merge the guarded live dataset M loader;
2. check out its exact reviewed `main` SHA on `ops-01`;
3. generate deterministic profile M with seed `20260914` before requesting the ephemeral OS Login key;
4. require explicit `ARP_CONFIRM_M8_DATASET_RESET=yes`;
5. transfer the generated bundle to a temporary directory on `db-01`;
6. execute the generated namespace-collision guard, reset/load, and `verify.sql` as local PostgreSQL user;
7. retain the manifest SHA-256 and verified row counts;
8. only after M succeeds, verify the deployed API subset and M7 telemetry before W1.

Do not run W1/W2 or performance tuning yet.

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
> M8 active plan의 첫 미완료 Phase 3 작업부터 진행하라.  
> M9 최적화나 speculative tuning을 M8로 끌어오지 마라.
