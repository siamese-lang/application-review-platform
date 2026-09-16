# M10 Reliability Evidence

Status: ACTIVE / R1-R3 COMPLETE / PHASE 5 NEXT

## Scope

M10 verifies bounded runtime failure behavior against the deployed Application Review Platform.
Phase 1 established the healthy control and evidence harness before fault injection.
R1 application process failure, R2 PostgreSQL outage, and R3a Garage non-endpoint node loss have now been executed and retained. R3b endpoint-node loss has not yet been injected.

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

Operational note: both R2 stop/start commands emitted a systemd warning that the unit or
drop-ins had changed on disk. Follow-up inspection found `NeedDaemonReload=yes`; a
`systemctl daemon-reload` cleared the stale manager state without restarting PostgreSQL.
The postmaster PID remained `96466`, the cluster stayed `active/running`, and
`pg_isready` continued to pass. R3a preflight subsequently required
`NeedDaemonReload=no`.

## Phase 4 / R3a Garage non-endpoint node loss

Run:

`m10-r3a-20260916T055354Z-af5421e5`

Artifact directory on ops-01:

`/srv/arp/repo/build/reliability/runs/m10-r3a-20260916T055354Z-af5421e5`

Source/release/dataset identity:

- source SHA: `af5421e50fc1c0b4cdd2fe4ce89d533dfb468197`;
- backend release: `d90eb558bdb6317d49b0a7ce82148ddeb4b5babf`;
- frontend release: `d90eb558bdb6317d49b0a7ce82148ddeb4b5babf`;
- Dataset M manifest:
  `9e174ead7c9ae7b77d5adc18c93e336b4cac5e30b5962bf47c31de4f42bea696`;
- deterministic overlay:
  `f93dfb6a030fa552de3dd4c7b9c022368079680bf2b16b13c05883e8b678aae1`.

Pre-fault Garage boundary:

- Garage version: `v2.4.1`;
- replication factor: 3;
- application endpoint: `storage-01:3900`;
- fault target: `storage-02/garage`;
- storage-01 and storage-03 were not intentionally stopped;
- storage-02 was confirmed in the Garage healthy set before injection.

Fault mechanism:

`docker stop --time 10 garage`

Restore mechanism:

`docker start garage`

Observed timing:

- fault command issued: `2026-09-16T05:54:28.511Z`;
- storage-02 container observed stopped: `2026-09-16T05:54:40.258Z`;
- restore command issued: `2026-09-16T05:55:43.488Z`;
- storage-02 observed back in Garage HEALTHY NODES:
  `2026-09-16T05:55:57.973Z`;
- observed stopped-state interval before restore: about **63.230 s**;
- restore command → healthy-set return: about **14.485 s**.

Garage cluster-state verification passed:

- storage-02 was absent from `HEALTHY NODES` during the fault;
- storage-02 returned to `HEALTHY NODES` after restore.

### Client/business continuity

R3a used the real HTTPS/session/CSRF boundary with two attachment-continuity VUs and two
non-attachment-continuity VUs for four minutes.

Observed attachment operations:

- attempts: 240;
- overall error rate: **0%**;
- upload error rate: **0%**;
- download error rate: **0%**;
- delete error rate: **0%**.

Observed non-attachment operations:

- attempts: 480;
- error rate: **0%**;
- support-path error rate: **0%**.

The retained driver also compared downloaded attachment bytes with the fixture payload.
No attachment continuity failure was observed while the non-endpoint replica node was down.

Result:

`M10_R3A_HYPOTHESIS=SUPPORTED`

### Fault-time business-state snapshot

The database snapshot was retained while storage-02 was still absent from the healthy set.

Observed counts:

- attachment DELETE_PENDING: 0;
- attachment FAILED: 0;
- attachment PENDING: 0;
- audit subject-count violations: 0;
- AVAILABLE attachment metadata incomplete: 0;
- IN_REVIEW application without reviewer: 0;
- non-DRAFT application/latest-history status mismatch: 0.

No unexpected partial attachment lifecycle state was observed during the fault.

### Telemetry isolation

Exact-window Prometheus evidence showed:

- PostgreSQL `pg_up`: min 1;
- application blackbox probe: min 1;
- storage-01 Garage `up`: min 1 / max 1;
- storage-02 Garage `up`: min 0 / max 1;
- storage-03 Garage `up`: min 1 / max 1.

Result:

`M10_R3A_TELEMETRY_NODE_ISOLATION=PASS`

The telemetry therefore captured the intended single-node `1 → 0 → 1` transition without
an unrelated PostgreSQL, application-probe, storage-01, or storage-03 outage.

### Application and post-recovery verification

The application process remained stable:

- MainPID before/after: `42960 → 42960`;
- no application restart was required.

The full deployed HTTPS smoke passed after Garage cluster recovery and revalidated:

- SPA/API routing;
- applicant registration/session/CSRF;
- application create/edit/submit;
- Garage attachment upload/download SHA-256 integrity;
- reviewer start/approve;
- final status/history.

The retained smoke application ID was `10408`.

Post-R3a database invariants remained clean:

- attachment DELETE_PENDING: 0;
- attachment FAILED: 0;
- attachment PENDING: 0;
- audit subject-count violations: 0;
- AVAILABLE attachment metadata incomplete: 0;
- IN_REVIEW application without reviewer: 0;
- non-DRAFT application/latest-history status mismatch: 0.

Results:

- `M10_R3A_DB_CORE_INVARIANTS=PASS`;
- `M10_R3A_ATTACHMENT_LIFECYCLE_CLEAN=PASS`;
- `M10_R3A_APPLICATION_STABLE=PASS`.

### R3a conclusion

The R3a hypothesis was supported for the observed single non-endpoint node loss:

- the faulted storage-02 Garage node actually left the healthy set;
- storage-01 remained the application endpoint and storage-03 remained healthy;
- attachment upload/download/delete continuity showed no errors;
- non-attachment requests showed no errors;
- PostgreSQL and the application probe stayed healthy;
- no partial attachment lifecycle state was observed during or after the fault;
- storage-02 returned to the cluster after manual container restore;
- no application restart or architecture change was required.

This result demonstrates observed service continuity for one non-endpoint Garage node loss.
It does **not** demonstrate application attachment availability when the fixed endpoint
storage-01 itself is unavailable.

## Phase 4 / R3b Garage fixed-endpoint node loss

Run:

`m10-r3b-20260916T061256Z-11b3a54f`

Artifact directory on ops-01:

`/srv/arp/repo/build/reliability/runs/m10-r3b-20260916T061256Z-11b3a54f`

Source/release/dataset identity:

- source SHA: `11b3a54f7e0a2798089773beef05bab51d350077`;
- backend release: `d90eb558bdb6317d49b0a7ce82148ddeb4b5babf`;
- frontend release: `d90eb558bdb6317d49b0a7ce82148ddeb4b5babf`;
- Dataset M manifest:
  `9e174ead7c9ae7b77d5adc18c93e336b4cac5e30b5962bf47c31de4f42bea696`;
- deterministic overlay:
  `f93dfb6a030fa552de3dd4c7b9c022368079680bf2b16b13c05883e8b678aae1`.

Pre-fault boundary:

- application Garage endpoint remained fixed at `http://10.40.0.41:3900`;
- fault target: `storage-01/garage`;
- storage-02 and storage-03 remained peer nodes and were not intentionally stopped;
- all three Garage containers were running `dxflrs/garage:v2.4.1`;
- storage-01 was confirmed healthy before the fault;
- application MainPID: `42960`;
- application `NRestarts=1`.

Fault mechanism:

`docker stop --time 10 garage`

Restore mechanism:

`docker start garage`

Observed timing:

- fault command issued: `2026-09-16T06:13:28.722Z`;
- storage-01 observed stopped: `2026-09-16T06:13:40.753Z`;
- restore command issued: `2026-09-16T06:14:43.746Z`;
- storage-01 returned to Garage `HEALTHY NODES`:
  `2026-09-16T06:15:00.310Z`;
- observed stopped-state interval before restore: about **62.993 s**;
- restore command → healthy-set return: about **16.564 s**.

Garage cluster verification passed:

- storage-01 left `HEALTHY NODES` during the fault;
- storage-01 returned after restore.

### Endpoint availability blast radius

The R3b driver created and verified a stable attachment before fault injection, then
continuously tested both that existing object and new attachment uploads while a separate
non-attachment flow remained active.

Observed attachment operations:

- attachment attempts: 237;
- overall attachment error rate: **28.6920%**;
- existing pre-fault attachment download error rate: **27.8481%**;
- new attachment upload error rate: **27.0042%**;
- download error rate for successfully uploaded objects: **0%**;
- delete error rate for successfully uploaded objects: **1.1561%**.

Observed unaffected paths:

- non-attachment attempts: 480;
- non-attachment error rate: **0%**;
- support-path error rate: **0%**.

Results:

- `M10_R3B_ENDPOINT_AVAILABILITY_GAP=OBSERVED`;
- `M10_R3B_NON_ATTACHMENT_CONTINUITY=PASS`;
- `M10_R3B_HYPOTHESIS=SUPPORTED`.

The result distinguishes object durability/replication from client-endpoint availability:
replicas remained present on the surviving Garage nodes, but the application could not
reliably access attachments while its single configured endpoint was unavailable.

### Fault-time attachment lifecycle state

While storage-01 was still absent from the healthy set, the retained database snapshot
showed:

- attachment DELETE_PENDING: 2;
- attachment FAILED: 22;
- attachment PENDING: 0;
- audit subject-count violations: 0;
- AVAILABLE attachment metadata incomplete: 0;
- IN_REVIEW application without reviewer: 0;
- non-DRAFT application/latest-history status mismatch: 0.

Result:

`M10_R3B_DURING_PARTIAL_ATTACHMENT_STATE=YES`

After Garage recovery and the post-fault smoke:

- attachment DELETE_PENDING: 2;
- attachment FAILED: 64;
- attachment PENDING: 0;
- core business invariants still passed;
- attachment lifecycle clean check failed.

Results:

- `M10_R3B_DB_CORE_INVARIANTS=PASS`;
- `M10_R3B_ATTACHMENT_LIFECYCLE_CLEAN=FAIL`;
- `M10_R3B_PARTIAL_STATE_RETAINED=YES`.

The full deployed HTTPS business smoke still passed after storage-01 recovery, including
new attachment upload/download SHA-256 integrity and the final application/history flow.
The retained smoke application ID was `10409`.

### Row-level residual evidence

A follow-up read-only database capture was retained before any manual reconciliation or
Dataset reset.

At that capture:

- FAILED rows: 64;
- DELETE_PENDING rows: 0;
- the 64 FAILED rows belonged only to the two R3b attachment-probe applications:
  - application `8200093613`: 32 rows;
  - application `8200093649`: 32 rows;
- all 64 rows had size `117` bytes and the same fixture SHA-256
  `205efb29fcde76a6b29a56a5f7e341f320d49e1afa0ecbc61d46a775e4c6a2bb`;
- their `created_at` range was
  `2026-09-16T06:13:41.785267Z` through
  `2026-09-16T06:14:43.537981Z`.

That row-creation interval lies entirely inside the observed storage-01 stopped interval
(`06:13:40.753Z` through restore command `06:14:43.746Z`), tying the retained FAILED
rows directly to the endpoint-outage upload attempts.

The two DELETE_PENDING rows observed immediately after R3b were no longer present in the
later read-only snapshot. The application reconciliation schedule is every ten minutes and
its implementation retries DELETE_PENDING rows, so automatic reconciliation is consistent
with that transition. No direct reconciliation execution log was retained, therefore the
exact mechanism is **not claimed as proven**.

The implementation does not automatically revisit FAILED rows during reconciliation.
Accordingly, the 64 retained FAILED rows are a persistent lifecycle residue unless a later
explicit cleanup/reset is performed.

### Telemetry isolation and process stability

Exact-window Prometheus evidence showed:

- PostgreSQL `pg_up`: min 1;
- application blackbox probe: min 1;
- storage-01 Garage `up`: min 0 / max 1;
- storage-02 Garage `up`: min 1 / max 1;
- storage-03 Garage `up`: min 1 / max 1.

Result:

`M10_R3B_TELEMETRY_NODE_ISOLATION=PASS`

The application process remained stable:

- MainPID before/after: `42960 → 42960`;
- no application restart was required.

Result:

`M10_R3B_APPLICATION_STABLE=PASS`

### R3b conclusion

The fixed Garage endpoint is a demonstrated application attachment-availability single
point of failure in the current architecture:

- one non-endpoint Garage node loss in R3a caused no observed attachment interruption;
- loss of the fixed endpoint storage-01 in R3b caused existing-object read and new-upload
  failures while PostgreSQL, the application process, non-attachment business flow, and the
  other two Garage nodes remained healthy;
- the endpoint outage also produced persistent FAILED attachment metadata rows;
- recovery of storage-01 restored normal business smoke without application restart;
- no HA architecture change has been made.

This is a retained negative reliability result, not a failed experiment.

## Next evidence boundary — Phase 5 residual reliability decision

R1-R3 are complete. The next decision must evaluate the two observed residual reliability
boundaries:

1. the single PostgreSQL primary remains a known DB-dependent application availability SPOF;
2. the fixed storage-01 Garage client endpoint is an observed attachment-availability SPOF
   and can leave FAILED attachment lifecycle residue.

Do not add database HA or a Garage endpoint load balancer/failover path silently. If a
corrective change crosses the frozen architecture boundary, document an ADR/explicit
architecture decision first. Otherwise retain the limitation and proceed to M10 closeout.
