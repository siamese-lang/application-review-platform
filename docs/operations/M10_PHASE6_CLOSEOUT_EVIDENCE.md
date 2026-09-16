# M10 Phase 6 Closeout Evidence

Status: FINAL
Milestone: M10 Reliability
Closeout date: 2026-09-16 UTC

## Scope

M10 verified bounded runtime failure behavior for the deployed Application Review Platform.
The executed scope remained:

- R1 application process failure;
- R2 PostgreSQL primary outage;
- R3 Garage single-node loss, split into non-endpoint and endpoint-node cases;
- R4 reused the already-completed M6 rollback evidence;
- R5 logical corruption/PITR remains M11 scope.

No second HA layer, PostgreSQL HA architecture, new object store, queue, cache, or managed
application service was added.

## R1 — application process failure

Retained run:

`m10-r1-20260916T032112Z-c6847aa8`

Observed:

- `arp.service` MainPID was killed with SIGKILL;
- systemd created a new MainPID after about 1.361 s;
- externally observed public API recovery took about 22.988 s from the fault;
- the existing PostgreSQL-backed session recovered without re-login;
- the static edge remained available;
- PostgreSQL and Garage remained healthy;
- full post-recovery business smoke and retained DB invariants passed.

Decision: no corrective architecture change.

## R2 — PostgreSQL primary outage

Retained run:

`m10-r2-20260916T041420Z-67f15273`

Observed:

- actual cluster unit: `postgresql@16-main.service`;
- bounded outage hold: 60 s;
- restore command → PostgreSQL ready: about 4.543 s;
- restore command → public API recovery: about 3.660 s;
- restore command → persisted-session recovery: about 3.734 s;
- application PID stayed unchanged;
- `pg_up` and application probe captured the outage/recovery;
- Hikari pending reached 61;
- Garage remained healthy;
- full post-recovery business smoke and core DB invariants passed.

Decision: retain the known single-primary availability limitation. PostgreSQL HA is not
introduced in M10.

## R3a — Garage non-endpoint node loss

Retained run:

`m10-r3a-20260916T055354Z-af5421e5`

Fault target: storage-02 Garage container.

Observed:

- storage-02 left the Garage healthy set and later returned;
- 240 attachment attempts completed with 0% observed upload/download/delete error;
- 480 non-attachment attempts completed with 0% observed error;
- no attachment lifecycle residue was created;
- PostgreSQL, application probe, storage-01, and storage-03 remained healthy;
- application PID remained stable;
- post-recovery business smoke passed.

Decision: no corrective change.

## R3b baseline — fixed Garage endpoint loss

Retained run:

`m10-r3b-20260916T061256Z-11b3a54f`

Pre-change application endpoint:

`http://10.40.0.41:3900`

Fault target: storage-01 Garage container.

Observed:

- overall attachment error rate: 28.6920%;
- existing pre-fault attachment download error rate: 27.8481%;
- new upload error rate: 27.0042%;
- download-after-successful-upload error rate: 0%;
- delete error rate: 1.1561%;
- non-attachment error rate: 0%;
- support-path error rate: 0%;
- PostgreSQL and the application probe remained healthy;
- storage-02 and storage-03 remained healthy;
- application PID remained stable;
- 64 FAILED attachment metadata rows remained after recovery.

The 64 FAILED rows were created entirely inside the observed storage-01 outage interval.
M3 explicitly defines FAILED as a durable terminal classification for upload/storage/
verification failure, so this was retained as failure evidence rather than silently cleaned
or reclassified.

Conclusion: Garage object replication did not guarantee application attachment availability
because the client endpoint itself was a single point of failure.

## Phase 5 corrective change — ADR-005

Accepted design:

`ADR-005 — Use an app-local Nginx proxy for Garage S3 endpoint failover`

Implemented runtime boundary:

- application endpoint: `http://127.0.0.1:3910`;
- Nginx listener: loopback-only `127.0.0.1:3910`;
- upstreams: storage-01/02/03 port 3900;
- incoming Host preserved for SigV4 compatibility;
- upstream retry enabled for error/timeout/502/503/504;
- app-to-Garage firewall target widened only from the obsolete endpoint tag to the existing
  `arp-storage` role tag;
- Garage replication factor and storage topology unchanged.

OpenTofu apply changed exactly two existing resources in place and added/destroyed nothing.
The repeated plan after apply reported no changes.

Ansible deployment on app-01 completed with:

- ok=36;
- changed=6;
- unreachable=0;
- failed=0.

Healthy-path runtime checks then verified:

- `127.0.0.1:3910` listener only;
- `GARAGE_ENDPOINT=http://127.0.0.1:3910`;
- all three Garage S3 upstreams reachable;
- local proxy reachable;
- full HTTPS business/attachment SHA-256 smoke passed (application 10410).

## R3b same-fault corrective-change retest

Retained run:

`m10-r3b-retest-20260916T071400Z-70e1b7f3`

Source SHA:

`70e1b7f3af1fc9022ccd3aeea2cf64c6cb036174`

Backend/frontend release:

`d90eb558bdb6317d49b0a7ce82148ddeb4b5babf`

Dataset M manifest:

`9e174ead7c9ae7b77d5adc18c93e336b4cac5e30b5962bf47c31de4f42bea696`

Deterministic overlay:

`f93dfb6a030fa552de3dd4c7b9c022368079680bf2b16b13c05883e8b678aae1`

Fault timing:

- fault command: 2026-09-16T07:14:35.387Z;
- storage-01 observed stopped: 2026-09-16T07:14:47.373Z;
- restore command: 2026-09-16T07:15:50.437Z;
- storage-01 healthy again: 2026-09-16T07:16:08.752Z.

Observed stopped-state interval before restore: about 63.064 s.

Observed result:

- attachment attempts: 240;
- overall attachment error rate: 0%;
- existing-object download error rate: 0%;
- upload error rate: 0%;
- download-after-upload error rate: 0%;
- delete error rate: 0%;
- non-attachment attempts: 480;
- non-attachment error rate: 0%;
- support-path error rate: 0%;
- fault-time FAILED/PENDING/DELETE_PENDING: 0/0/0;
- post-run FAILED/PENDING/DELETE_PENDING: 0/0/0;
- PostgreSQL `pg_up`: min 1;
- application probe: min 1;
- storage-01 Garage: min 0 / max 1;
- storage-02 Garage: min 1 / max 1;
- storage-03 Garage: min 1 / max 1;
- application MainPID: 47204 → 47204;
- post-recovery full HTTPS business smoke passed (application 10411).

Retained verdicts:

- `M10_R3B_RETEST_ATTACHMENT_CONTINUITY=PASS`;
- `M10_R3B_RETEST_NON_ATTACHMENT_CONTINUITY=PASS`;
- `M10_R3B_RETEST_CORRECTIVE_CHANGE=VERIFIED`;
- `M10_R3B_TELEMETRY_NODE_ISOLATION=PASS`;
- `M10_R3B_APPLICATION_STABLE=PASS`;
- `M10_R3B_RETEST_ATTACHMENT_LIFECYCLE_CLEAN=PASS`.

The guarded Dataset M reset before the retest intentionally reset the live synthetic dataset.
Therefore the earlier 64 FAILED rows are not claimed to have been automatically reconciled.
Their row-level baseline evidence remains retained; the retest claim is that the new same
fault produced no new lifecycle residue.

## Before/after result

| Measurement | R3b baseline | ADR-005 same-fault retest |
| --- | ---: | ---: |
| Attachment error rate | 28.6920% | 0% |
| Existing-object download error | 27.8481% | 0% |
| Upload error | 27.0042% | 0% |
| Download-after-upload error | 0% | 0% |
| Delete error | 1.1561% | 0% |
| Non-attachment error | 0% | 0% |
| Post-run FAILED rows | 64 | 0 new rows |

This is a same-fault revalidation of the measured endpoint availability problem.

## R4 and R5 disposition

R4 is satisfied by the M6 exact immutable release and schema-compatible rollback evidence.
It was not rerun merely to duplicate an already-retained E5 result.

R5 logical corruption/PITR remains M11 scope.

## Temporary load-generator closeout

M10 reused the repository-defined temporary Tokyo load generator for sustained fault probes.

Closeout plan with `enable_loadgen=false` contained exactly four destroy actions:

- `google_compute_instance.loadgen[0]`;
- `google_compute_router.loadgen[0]`;
- `google_compute_router_nat.loadgen[0]`;
- `google_compute_subnetwork.loadgen[0]`.

Apply result:

- 0 added;
- 0 changed;
- 4 destroyed.

A subsequent persistent-runtime OpenTofu plan reported:

`No changes. Your infrastructure matches the configuration.`

The retained Seoul runtime therefore has no unexplained OpenTofu drift after M10 closeout.

## Final limitations

M10 does not prove:

- PostgreSQL HA or transparent primary failover;
- multi-region application availability;
- arbitrary network-partition tolerance;
- multi-node simultaneous Garage loss;
- disk corruption recovery;
- backup/PITR correctness.

The single PostgreSQL primary remains the main documented availability limitation from M10
and is not silently redesigned.

## M10 conclusion

M10 is complete from the runtime/evidence perspective.

The strongest new reliability result is the Garage endpoint story:

1. one non-endpoint replica loss caused no observed client interruption;
2. loss of the fixed client endpoint caused material attachment failures despite surviving
   replicas;
3. telemetry isolated the fault to that endpoint while unrelated business paths stayed
   healthy;
4. one bounded app-local proxy change was selected through ADR-005;
5. the same storage-01 fault was repeated and attachment/non-attachment errors became 0% with
   no new lifecycle residue;
6. the temporary test infrastructure was removed and the persistent runtime finished no-drift.
