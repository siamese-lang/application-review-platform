# M10 Reliability Evidence

Status: ACTIVE / PHASE 1 HEALTHY CONTROL COMPLETE

## Scope

M10 verifies bounded runtime failure behavior against the deployed Application Review Platform.
Phase 1 establishes the healthy control and evidence harness before any fault is injected.

No R1/R2/R3 fault has been injected yet.

## Repository/runtime identity

Healthy-control repository source:

`6d5f6ae8849ae8b70a369eb58ee48ddd666b447f`

Deployed component releases during the control:

- backend: `d90eb558bdb6317d49b0a7ce82148ddeb4b5babf`;
- frontend: `d90eb558bdb6317d49b0a7ce82148ddeb4b5babf`.

Dataset:

- profile: M;
- seed: `20260914`;
- manifest SHA-256:
  `9e174ead7c9ae7b77d5adc18c93e336b4cac5e30b5962bf47c31de4f42bea696`;
- deterministic interactive overlay SHA-256:
  `f93dfb6a030fa552de3dd4c7b9c022368079680bf2b16b13c05883e8b678aae1`.

Persistent Seoul runtime remained:

- edge-01;
- app-01;
- db-01;
- storage-01;
- storage-02;
- storage-03;
- ops-01;
- obs-01.

## Temporary M10 load generator lifecycle

M9 had removed the prior temporary Tokyo load generator.

For M10 Phase 1, the existing repository-defined topology was reused rather than redesigned.

Reviewed OpenTofu create plan contained exactly four create actions:

- `google_compute_instance.loadgen[0]`;
- `google_compute_router.loadgen[0]`;
- `google_compute_router_nat.loadgen[0]`;
- `google_compute_subnetwork.loadgen[0]`.

No Seoul runtime resource was changed.

Apply result:

- 4 added;
- 0 changed;
- 0 destroyed.

Load-generator identity:

- name: `loadgen-01`;
- region: `asia-northeast1`;
- zone: `asia-northeast1-a`;
- private IP: `10.50.0.10`;
- machine type: repository default `e2-standard-2`.

The existing Ansible loadgen role was then applied.

Observed play recap:

- ok: 8;
- changed: 2;
- unreachable: 0;
- failed: 0.

Pinned k6 version verification passed.

Read-only runtime preflight then verified:

- SSH access to loadgen-01;
- pinned k6 available;
- loadgen-01 reached the deployed HTTPS API through the real public edge path;
- DNS resolution/outbound access was available.

The load generator is temporary M10 test infrastructure and remains subject to the M10
closeout lifecycle decision.

## Phase 1 healthy control

Run:

`m10-control-20260916T025311Z-6d5f6ae8`

Artifact directory on ops-01:

`/srv/arp/repo/build/reliability/runs/m10-control-20260916T025311Z-6d5f6ae8`

Control profile:

- no fault injected;
- 5 minutes;
- 30 VUs;
- Dataset M;
- W2-derived normal-load business semantics;
- real HTTPS/session/CSRF boundary;
- business mix target 40/15/10/20/10/5.

Observed business requests:

- total: 8,905;
- list/detail: 3,572, 40.11%;
- create/save: 1,336, 15.00%;
- submit/resubmit: 885, 9.94%;
- reviewer queue/detail: 1,776, 19.94%;
- review action: 888, 9.97%;
- attachment: 448, 5.03%.

Control result:

- non-file success rate: **100.0000%**;
- non-file p95: **90.339 ms**;
- normal-load control target: **PASS**.

The full deployed HTTPS smoke also completed successfully after the workload. It revalidated:

- SPA/API edge routing;
- registration/session/CSRF;
- application create/edit/submit flow;
- Garage attachment upload/download SHA-256 integrity;
- reviewer start/approve;
- final application status/history.

## Database business invariants

Post-control invariant result:

- attachment DELETE_PENDING: 0;
- attachment FAILED: 0;
- attachment PENDING: 0;
- audit subject-count violations: 0;
- AVAILABLE attachment metadata incomplete: 0;
- IN_REVIEW application without reviewer: 0;
- non-DRAFT application/latest-history status mismatch: 0.

Overall:

`M10_DB_INVARIANTS=PASS`

These checks are deliberately narrower than a claim of global database correctness. They are
the retained M10 fault-experiment invariants that will be compared after R1–R3.

## Telemetry evidence

The control runner retained a manifest-aligned Prometheus query window covering the exact
control interval.

Captured families include:

- private application probe;
- PostgreSQL `pg_up`;
- Hikari active/pending;
- db-01 CPU;
- app-01 CPU;
- Garage up status by node.

The captured telemetry is stored with the run artifacts. Phase 1 did not require a new
observability product or new persistent telemetry path.

## Phase 1 conclusion

Phase 1 is complete.

The harness now demonstrates all required pre-fault capabilities:

- exact source/release/dataset identity;
- deterministic normal synthetic workload;
- real edge/API/session boundary;
- workload-family measurements;
- post-run full business smoke;
- database invariants;
- exact-window telemetry capture;
- retained run artifacts.

The healthy control passed before any deliberate fault was introduced.

M10 may therefore proceed to Phase 2 / R1 application process failure.

## Next evidence boundary — R1

Before fault injection, inspect and retain the live app-01 systemd state:

- exact unit name;
- MainPID;
- ActiveState/SubState;
- Restart policy;
- RestartSec;
- NRestarts;
- current backend release identity.

The initial R1 failure mechanism must exercise `Restart=on-failure`; an intentional
`systemctl stop` is not an equivalent crash test.

Do not inject the fault until the live unit/process state is confirmed.
