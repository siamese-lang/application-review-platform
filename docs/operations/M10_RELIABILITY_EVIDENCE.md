# M10 Reliability Evidence

Status: ACTIVE / R1-R2 COMPLETE / R3 NEXT

## Scope

M10 verifies bounded runtime failure behavior against the deployed Application Review Platform.
Phase 1 established the healthy control and evidence harness before fault injection.
R1 application process failure and R2 PostgreSQL outage have now been executed and retained. R3 has not yet been injected.

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

## Phase 3 / R2 PostgreSQL outage during normal synthetic workload

Run:

`m10-r2-20260916T041420Z-67f15273`

Artifact directory on ops-01:

`/srv/arp/repo/build/reliability/runs/m10-r2-20260916T041420Z-67f15273`

Source/release/dataset identity:

- source SHA: `67f15273333ff0f4d6f4d30533179f691f8ddb57`;
- backend release: `d90eb558bdb6317d49b0a7ce82148ddeb4b5babf`;
- frontend release: `d90eb558bdb6317d49b0a7ce82148ddeb4b5babf`;
- Dataset M manifest:
  `9e174ead7c9ae7b77d5adc18c93e336b4cac5e30b5962bf47c31de4f42bea696`;
- deterministic overlay:
  `f93dfb6a030fa552de3dd4c7b9c022368079680bf2b16b13c05883e8b678aae1`.

Pre-fault database boundary:

- PostgreSQL: 16/main, port 5432;
- actual cluster unit: `postgresql@16-main.service`;
- pre-fault postmaster PID: `23479`;
- `postgresql.service` was the active/exited umbrella unit rather than the cluster process;
- Alloy remained a separate active/running process;
- application MainPID: `42960`;
- application `NRestarts=1`.

Fault mechanism:

`systemctl stop postgresql@16-main.service`

Restore mechanism:

`systemctl start postgresql@16-main.service`

The cluster unit only was stopped. The VM, application process, Nginx, Garage, and Alloy
were not intentionally stopped.

Fault/start timing:

- stop command issued: `2026-09-16T04:15:01.925Z`;
- database observed stopped: `2026-09-16T04:15:05.031Z`;
- bounded outage hold: 60 s;
- start command issued: `2026-09-16T04:16:05.037Z`;
- database ready: `2026-09-16T04:16:09.580Z`;
- restore command → PostgreSQL ready: **4.543 s**;
- postmaster PID: `23479 → 96466`.

The existing five-minute PostgreSQL alert delay was intentionally not exercised. The fault
window was kept bounded rather than extended merely to make an alert fire.

### Observed blast radius and recovery

Public API:

- first observed DOWN:
  `2026-09-16T04:15:33.283Z`;
- first observed UP:
  `2026-09-16T04:16:08.697Z`;
- fault command → first observed API DOWN: **31.358 s**;
- DB restore command → first observed API recovery: **3.660 s**;
- full-run public-API probe error rate: **0.2548%**.

Persisted applicant session:

- first observed DOWN:
  `2026-09-16T04:16:03.260Z`;
- first observed UP:
  `2026-09-16T04:16:08.771Z`;
- DB restore command → session recovery: **3.734 s**;
- session probe error rate: **0.1304%**;
- session login attempts remained **1**, so recovery did not depend on reauthentication.

Static edge:

- error rate: **0%**;
- no static-edge DOWN transition was observed.

The delayed first observed API/session failure does not mean PostgreSQL remained usable for
that long. The probes only record when a DB-dependent request next reached a path that
required the unavailable database. The server-side telemetry below captured the DB outage
directly.

### Application/Hikari behavior

The application process did not restart:

- MainPID before/after: `42960 → 42960`;
- `NRestarts: 1 → 1`;
- recovery without application restart/redeploy: **PASS**.

Hikari pending connections reached a maximum of **61** during the retained window.

After PostgreSQL returned, the existing application process and connection pool recovered
without a backend redeploy.

### Telemetry blast radius

Manifest-aligned Prometheus evidence captured both outage and recovery:

- PostgreSQL `pg_up`: min 0 / max 1;
- application blackbox probe: min 0 / max 1;
- Hikari pending: max 61;
- Garage `up`: min 1.

Result:

`M10_R2_TELEMETRY_BLAST_RADIUS=PASS`

Garage remained healthy while PostgreSQL and the DB-dependent application health path became
unavailable, supporting the intended single-fault attribution.

### Workload interpretation

The R2 driver retained the same 30 business-VU allocation and W2-derived per-family pacing,
plus three low-rate boundary probes. It recorded 3,852 business attempts.

Observed attempt proportions during the faulted run were:

- list/detail: 36.42% vs 40% reference;
- create/save: 13.66% vs 15%;
- submit/resubmit: 17.96% vs 10%;
- reviewer queue/detail: 18.22% vs 20%;
- review action: 9.11% vs 10%;
- attachment: 4.62% vs 5%.

These percentages are **not claimed as a preserved W2 mix**. Under constant-VU execution,
different endpoint latency/failure behavior changes iteration throughput during a database
outage. The retained R2 condition is therefore described as the same 30-VU allocation,
dataset, business families, and pacing semantics—not an arrival-rate-controlled exact mix.

Full-run rates:

- support error rate: 0.4290%;
- non-file error rate: 0.2712%;
- static-edge error rate: 0%.

The error rates cover the complete five-minute run, so they dilute the deliberately bounded
60-second fault interval and are not outage-only failure percentages.

### Post-recovery business/state verification

The full deployed HTTPS smoke passed after database recovery and exercised:

- SPA/API routing;
- applicant registration/session;
- application create/edit/submit;
- Garage attachment upload/download SHA-256 integrity;
- reviewer start/approve;
- final status/history.

The retained smoke application ID was `10407`.

Post-R2 database invariants:

- attachment DELETE_PENDING: 0;
- attachment FAILED: 0;
- attachment PENDING: 0;
- audit subject-count violations: 0;
- AVAILABLE attachment metadata incomplete: 0;
- IN_REVIEW application without reviewer: 0;
- non-DRAFT application/latest-history status mismatch: 0.

Overall:

`M10_R2_DB_CORE_INVARIANTS=PASS`

No partial attachment lifecycle state was observed after recovery.

### R2 conclusion

The primary R2 hypothesis was supported:

- the single PostgreSQL primary is an application availability dependency;
- DB-dependent API/session behavior became unavailable while the static edge remained up;
- `pg_up` and the application blackbox probe captured the outage;
- Hikari pending rose materially during the fault;
- Garage remained healthy;
- after PostgreSQL was started, DB readiness returned in about 4.54 s;
- API/session access recovered in about 3.7 s from the restore command;
- the existing application process recovered without restart or redeploy;
- post-recovery representative business flow and retained DB invariants passed.

This is retained as evidence of the known single-primary availability boundary, not as a
failed experiment and not as justification for silently adding database HA.

Operational note: both stop/start commands emitted a systemd warning that the unit or
drop-ins had changed on disk and suggested `systemctl daemon-reload`. The commands and
recovery succeeded, but `NeedDaemonReload` must be inspected before R3 rather than ignored.

## Next evidence boundary — R3

Before any Garage fault:

1. confirm PostgreSQL and application remain healthy after R2;
2. inspect `NeedDaemonReload` for the PostgreSQL cluster unit and system manager;
3. inspect the live Garage container/service identity and cluster state on storage-01/02/03;
4. confirm storage-01 is still the application endpoint;
5. execute R3a on a non-endpoint node first, restore/verify health, then execute R3b on the
   endpoint node.

Do not stop a Garage container until the exact live container identity and cluster state are
confirmed.
