# M11 Phase 3 Verified Whole-System Checkpoint Evidence

Status: VERIFIED LIVE  
Milestone: M11 Disaster Recovery  
Evidence date: 2026-09-16 UTC  
Successful checkpoint repository main SHA: `7bdf3b51d25d7caceade2d9ce09a6a587960bff3`

## Scope

Phase 3 verified one maintenance checkpoint spanning PostgreSQL and Garage without claiming a
distributed transaction or common storage snapshot.

The retained consistency boundary was:

`edge mutation block + drain → application stop → attachment lifecycle checks → PostgreSQL
full backup → Garage copy/manifest → backup verification → application health → edge mutation
block removal → representative business smoke`

Stopping the application after the edge drain was necessary because
`AttachmentReconciliationService` can update attachment rows and Garage objects on its
scheduled path without receiving a public HTTP mutation.

This evidence does not claim:

- full DR recovery;
- full-system RPO/RTO;
- PostgreSQL automatic failover;
- multi-region HA;
- that Garage replication alone is a backup.

## Mutation-block mechanism

The checkpoint mutation guard is installed in both Nginx API locations:

- exact `/api`;
- prefix `/api/`.

When enabled, only `POST`, `PUT`, `PATCH`, and `DELETE` receive HTTP 503. Read methods
remain available.

Independent live gate verification before the checkpoint:

- gate enabled at `2026-09-16T11:37:02Z`;
- pre-reload Nginx workers drained: 2;
- public GET check: HTTP 200;
- public POST check: HTTP 503;
- gate disabled at `2026-09-16T11:38:00Z`;
- pre-reload Nginx workers drained on disable: 2;
- final state: `M11_MUTATION_GATE=DISABLED`.

The gate uses Nginx reload rather than restart and waits for the pre-reload worker PIDs to exit.

## Successful checkpoint identity

Checkpoint ID:

`m11-checkpoint-20260916T121255Z`

Checkpoint execution started from repository main:

`7bdf3b51d25d7caceade2d9ce09a6a587960bff3`

Observed sequence:

- initial gate state: DISABLED;
- gate enabled: `2026-09-16T12:13:08Z`;
- drained Nginx workers: 2;
- application state after stop: INACTIVE;
- attachment lifecycle snapshot:
  - PENDING: 0;
  - DELETE_PENDING: 0;
  - AVAILABLE: 17;
  - FAILED: 0;
  - total rows: 17;
- frozen cross-store interval start:
  `2026-09-16T12:13:11.077Z`.

The application process remained stopped during PostgreSQL and Garage backup creation so the
scheduled reconciliation path could not mutate either store during the checkpoint.

## PostgreSQL checkpoint backup

pgBackRest full backup:

`20260916-121314F`

Observed pgBackRest facts:

- backup command began: `2026-09-16 12:13:13.038 UTC`;
- immediate checkpoint completed and backup start was accepted;
- backup start archive:
  `000000010000000200000087`;
- backup start LSN:
  `2/87000028`;
- backup stop archive:
  `000000010000000200000087`;
- backup stop LSN:
  `2/87000138`;
- full backup size: 381.3 MB;
- file total: 1,358;
- repository size: 56,862,801 bytes;
- pgBackRest backup duration: 64,181 ms;
- backup completed successfully.

The repository listed the successful checkpoint backup with `error=false`.

## Backup retention observation

The pgBackRest repository is configured with:

`repo1-retention-full=2`

When `20260916-121314F` completed, pgBackRest expired the earlier Phase 1 full backup:

`20260916-090503F`

and removed archive segments through:

`000000010000000200000082`

At that point the repository retained the two newer full backups:

- `20260916-120507F` — created during an earlier failed Phase 3 attempt before Garage backup
  completed;
- `20260916-121314F` — the verified Phase 3 checkpoint database backup.

The historical Phase 2 PITR evidence from `20260916-090503F` remains valid as already-retained
experiment evidence, but that old full backup is no longer a current repository restore source.
Phase 4 must use the verified Phase 3 checkpoint backup identity.

## Garage independent object backup

The Garage checkpoint object backup ran on `backup-01`.

Ansible result:

- backup-01: ok=4;
- changed=1;
- unreachable=0;
- failed=0.

Verified object set:

- bucket: `application-review`;
- object count: 21;
- manifest:
  `/srv/backup/objects/checkpoints/m11-checkpoint-20260916T121255Z/manifest.json`;
- manifest SHA-256:
  `b6749631671f489160740c6e27c30d4aedb69e8cc80914cfc8253129ed0607c8`;
- manifest verification:
  `M11_OBJECT_BACKUP_VERIFY=PASS`.

The manifest retained on the independent backup disk contains, for each object:

- object key;
- backup file path;
- size;
- SHA-256;
- backup timestamp.

The verifier re-read every backup file and required the recorded size and SHA-256 to match.

## Cross-store invariants

Attachment lifecycle counts before backup:

`0|0|17|0|17`

interpreted as:

`PENDING|DELETE_PENDING|AVAILABLE|FAILED|TOTAL`

Attachment lifecycle counts after both PostgreSQL and Garage backup verification:

`0|0|17|0|17`

The counts did not change while the application mutation path was frozen.

This check does not by itself prove every business invariant; it proves that the attachment
lifecycle state used to define the cross-store checkpoint boundary stayed stable through the
backup sequence.

## Checkpoint timing

Frozen interval start:

`2026-09-16T12:13:11.077Z`

Complete backup set verified:

`2026-09-16T12:14:27.795Z`

Writes resumed after application health and final mutation-gate removal:

`2026-09-16T12:14:49.788Z`

Measured durations:

- frozen start → backup-set verification: **76.718 seconds**;
- frozen start → writes resumed: **98.711 seconds**.

These are checkpoint maintenance-window measurements, not full DR RTO.

## Resume and business verification

After backup verification:

- `arp.service` was started;
- local management health returned UP;
- checkpoint output reported
  `M11_CHECKPOINT_APP_STATE=HEALTHY`;
- mutation gate disable drained 2 Nginx workers;
- final mutation gate state:
  `M11_MUTATION_GATE=DISABLED`;
- checkpoint result:
  `M11_CHECKPOINT=PASS checkpoint_id=m11-checkpoint-20260916T121255Z`.

Representative public HTTPS business smoke then passed after writes resumed.

Verified workflow:

- SPA root;
- SPA deep-link fallback;
- public programs API;
- applicant registration with CSRF;
- applicant login/session;
- structured draft creation;
- Garage attachment upload;
- applicant attachment download SHA-256 integrity;
- draft edit;
- submit;
- reviewer login/session;
- start review;
- reviewer attachment download SHA-256 integrity;
- approve;
- final applicant state/history.

Final smoke result:

`PASS: HTTPS SPA/API, registration/session/CSRF, application edit/submit, Garage attachment
SHA-256 integrity, reviewer start/approve, and final history (application 10412).`

## Failed attempts retained as evidence

Phase 3 exposed three bounded implementation defects before the successful checkpoint.

### Missing executable mode

The first direct checkpoint invocation failed immediately:

`-bash: scripts/backup/run-m11-checkpoint.sh: Permission denied`

Root cause:

- the new checkpoint shell scripts were committed as mode `100644`.

Corrective change:

- checkpoint and mutation-gate scripts are executable `100755`;
- the Phase 3 static contract rejects future loss of executable mode.

No gate, application stop, database backup, or object backup had started before this failure.

### Java SIGTERM exit-status contract

The next attempt enabled the gate and gracefully stopped Spring Boot/Tomcat, but systemd left
`arp.service` in failed state.

Observed shutdown:

- Tomcat graceful shutdown completed;
- JPA EntityManagerFactory closed;
- Hikari shutdown completed;
- JVM exited with status 143 after SIGTERM;
- systemd treated 143 as failure.

Corrective change:

- `arp.service` now declares `SuccessExitStatus=143`;
- the M11 contract requires that unit setting.

Cleanup restarted the application and only then disabled the mutation gate.

No checkpoint PostgreSQL/Garage backup began during that attempt.

### Temporary Ansible inventory parsing

A later attempt reached the object-backup step after producing a PostgreSQL full backup, but
the object-backup Ansible play matched zero hosts and returned rc=0.

Live diagnosis showed:

- OpenTofu inventory contained `backup-01` with `role=backup`;
- generated YAML content was correct;
- the checkpoint script wrote that YAML to a plain extensionless `mktemp` path;
- Ansible did not select its YAML inventory plugin and attempted the INI parser instead;
- no inventory was parsed and only implicit localhost remained.

Corrective change:

- checkpoint inventory now uses
  `/tmp/m11-checkpoint-inventory.XXXXXX.yml`;
- the Phase 3 static contract requires the YAML suffix.

The PostgreSQL backup from that failed attempt, `20260916-120507F`, is retained only as a
partial artifact. Because no matching Garage manifest was produced, it is not a verified
whole-system checkpoint.

Cleanup again restarted the application and returned the mutation gate to DISABLED.

## Phase 3 conclusion

M11 Phase 3 is complete.

Verified claims:

1. new public API mutations can be blocked while reads remain available;
2. pre-block Nginx workers are drained before the frozen backup interval;
3. scheduled background reconciliation is stopped by stopping the application process;
4. no `PENDING` or `DELETE_PENDING` attachment state exists at the successful checkpoint;
5. PostgreSQL full backup `20260916-121314F` completed with the recorded WAL/LSN identity;
6. 21 Garage objects were copied to the independent repository and every copied file passed
   manifest size/SHA-256 verification;
7. attachment lifecycle counts remained unchanged through backup verification;
8. the application returned healthy, the mutation block was removed, and the full representative
   HTTPS business workflow passed after writes resumed.

Immediate next phase:

**Phase 4 — full DR rebuild and business recovery.**
