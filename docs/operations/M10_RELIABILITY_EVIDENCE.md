# M10 Reliability Evidence

Status: ACTIVE / R1 COMPLETE / R2 NEXT

## Scope

M10 verifies bounded runtime failure behavior against the deployed Application Review Platform.
Phase 1 established the healthy control and evidence harness before fault injection.
R1 application process failure has now been executed and retained. R2/R3 have not yet been injected.

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

## Phase 2 / R1 application process failure

Run:

`m10-r1-20260916T032112Z-c6847aa8`

Artifact directory on ops-01:

`/srv/arp/repo/build/reliability/runs/m10-r1-20260916T032112Z-c6847aa8`

Source and release identity:

- source SHA: `c6847aa83eabc8fafad700c09e78bbfd3f290a94`;
- backend release: `d90eb558bdb6317d49b0a7ce82148ddeb4b5babf`.

Pre-fault live state:

- unit: `arp.service`;
- state: `active/running`;
- MainPID: `39661`;
- `Restart=on-failure`;
- effective restart delay reported by systemd: 100 ms;
- `NRestarts=0`.

Fault mechanism:

`systemctl kill --kill-who=main --signal=SIGKILL arp.service`

The VM, PostgreSQL, Garage, and Nginx were not intentionally stopped.

Fault timestamp:

`2026-09-16T03:21:48.378Z`

Systemd automatic restart observation:

- new MainPID: `42960`;
- restart observed at: `2026-09-16T03:21:49.739Z`;
- fault → new active MainPID observation: **1.361 s**;
- `NRestarts: 0 → 1`;
- automatic restart check: **PASS**.

This distinction matters: systemd restarted the Java process quickly, but process existence
was not treated as service recovery.

### Observed client blast radius and business recovery

Public API:

- first observed DOWN:
  `2026-09-16T03:21:49.362Z`;
- first observed UP after the outage:
  `2026-09-16T03:22:11.366Z`;
- observed DOWN→UP interval: **22.004 s**;
- fault → first recovered public API observation: **22.988 s**;
- R1 public-API probe error rate across the full run: **12.1113%**.

Persisted applicant session:

- first observed DOWN:
  `2026-09-16T03:21:49.378Z`;
- first observed UP:
  `2026-09-16T03:22:11.380Z`;
- observed DOWN→UP interval: **22.002 s**;
- session probe error rate across the full run: **12.2720%**;
- login attempts during the probe run: **1**.

The session probe did not reauthenticate after the crash. The pre-existing PostgreSQL-backed
session became usable again after the application recovered, so persisted-session recovery
passed.

Static edge:

- static-edge probe error rate: **0%**;
- no static-edge DOWN transition was observed.

The measured blast radius therefore matched the service boundaries: the backend API/session
path was interrupted while the Nginx-served static edge remained available.

### Unrelated data-service state

Exact-window Prometheus evidence retained:

- PostgreSQL `pg_up`: 13 samples, all healthy;
- Garage `up`: 39 node samples, all healthy.

Result:

`M10_R1_UNRELATED_DATA_SERVICES_HEALTHY=PASS`

This supports attribution of the observed outage to the application process failure rather
than a coincident PostgreSQL or Garage outage.

### Post-recovery business verification

The full deployed HTTPS smoke passed after R1 and exercised:

- SPA/API routing;
- applicant registration and session;
- application create/edit/submit;
- Garage attachment upload/download SHA-256 integrity;
- reviewer start/approve;
- final status/history.

The retained smoke application ID was `9885`.

Post-R1 database invariants:

- attachment DELETE_PENDING: 0;
- attachment FAILED: 0;
- attachment PENDING: 0;
- audit subject-count violations: 0;
- AVAILABLE attachment metadata incomplete: 0;
- IN_REVIEW application without reviewer: 0;
- non-DRAFT application/latest-history status mismatch: 0.

Overall:

`M10_R1_DB_INVARIANTS=PASS`

### R1 conclusion

The original R1 hypothesis was supported by the retained run:

- a Java-process crash interrupted API/session access;
- systemd automatically restarted the service without redeployment;
- the process itself was observed restarted after about 1.36 s;
- actual externally observed API/session recovery took about 23 s;
- the existing PostgreSQL-backed session survived and required no re-login;
- the static edge remained available;
- PostgreSQL and Garage remained healthy;
- the representative business flow and retained database invariants were correct after
  recovery.

No corrective change is justified from R1 alone. In particular, no redundant application
replica is added merely to eliminate a bounded single-process restart interval.

The useful reliability result is the gap between **process restart time** and **business
recovery time**: operational recovery must be measured at the user/API boundary, not from
`systemctl active` alone.

## Next evidence boundary — R2

Before injecting a PostgreSQL outage, inspect and retain the actual db-01 service/cluster
state and select the reversible service-level stop/start command from that live state.

Confirm at minimum:

- PostgreSQL service/unit or cluster identity;
- active/running state;
- PostgreSQL version/cluster/port;
- current postmaster PID;
- exporter state separately from the database service;
- application service remains healthy before the fault.

Do not inject R2 until the live database service boundary is confirmed.
