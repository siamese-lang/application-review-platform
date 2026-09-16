# M11 Phase 2 PostgreSQL PITR Evidence

Status: VERIFIED LIVE  
Milestone: M11 Disaster Recovery  
Evidence date: 2026-09-16 UTC  
Successful restore repository main SHA: `947b9b387ec5f1974d5cf657dcd4cecd89207104`

## Scope

Phase 2 verified PostgreSQL point-in-time recovery independently from full-system DR.

The experiment restored the retained pgBackRest backup/WAL archive into a separate disposable
recovery database VM. The retained Seoul `db-01` was never overwritten.

This evidence does not claim:

- PostgreSQL automatic failover;
- whole-system DR;
- attachment/object recovery;
- full-system RPO/RTO.

## Recovery infrastructure

Reviewed OpenTofu plan:

- 4 create;
- 0 change;
- 0 destroy.

Applied result:

- 4 added;
- 0 changed;
- 0 destroyed.

Created recovery resources:

- `recovery-db-01`;
- private IP `10.60.0.20`;
- zone `asia-northeast1-a`;
- machine type `e2-medium`;
- no public IP;
- no attached service account;
- independent 30 GB `pd-standard` recovery data disk;
- only backup-01 ↔ recovery-db-01 TCP/22 paths for pgBackRest.

Preflight:

- OS Login / Ansible ping: PASS;
- recovery disk device present: PASS;
- recovery disk initially unmounted.

## Recovery host preparation

Final recovery-host play recap:

- `recovery-db-01`: ok=26, changed=15, unreachable=0, failed=0.

Verified pre-restore state:

- PostgreSQL installed;
- pgBackRest installed;
- recovery disk mounted at `/srv/postgresql`;
- recovery data directory created without `initdb`;
- PostgreSQL start mode set to manual;
- PostgreSQL stopped before PITR;
- PostgreSQL configured to listen only on localhost;
- recovery postgres account authorized to access `backup-01` only through forced pgBackRest SSH;
- backup host key pinned;
- recovery/repository pgBackRest versions matched exactly;
- retained repository was readable from the recovery host.

## Synthetic marker and PITR target

Marker code:

`M11-PITR-20260916T104401Z`

The experiment used one temporary synthetic DRAFT program row and did not modify existing
application/history/attachment rows.

Observed committed states:

- PRE visible: `2026-09-16T10:44:12.233261+00`;
- PITR target: `2026-09-16T10:44:13.321143+00`;
- POST visible: `2026-09-16T10:44:14.485875+00`;
- forced WAL switch LSN: `2/7E000818`;
- retained live state before recovery: `M11_PITR_POST`.

The PRE commit preceded the target by 1.087882 seconds.

The POST commit followed the target by 1.164732 seconds.

This creates an unambiguous target boundary: the recovered database must contain PRE and must
not contain POST.

## Restore source and command

Retained pgBackRest full backup:

`20260916-090503F`

The restore ran on `recovery-db-01` with:

- time-based recovery;
- target `2026-09-16 10:44:13.321143+00`;
- `target-action=promote`;
- repository host `10.60.0.10`;
- local restore path `/srv/postgresql/data`.

pgBackRest selected backup set `20260916-090503F` and reported:

- restore start from backup point `2026-09-16 09:05:03`;
- restored size: 381.3 MB;
- restored files: 1,358;
- pgBackRest restore duration: 15,227 ms;
- restore command completed successfully.

## PITR verification

Recovered marker state:

`M11_PITR_PRE`

Verification results:

- PRE included: PASS;
- POST excluded: PASS;
- orphan applications: 0;
- application/latest-history status mismatch: 0;
- terminal applications missing terminal history: 0;
- overall PITR restore verification: PASS.

Measured timings from the repository-owned recovery script:

- pgBackRest restore complete: 15,329 ms;
- PostgreSQL ready: 25,601 ms;
- business/data verification complete: 27,229 ms.

For this experiment, the verified DB PITR RTO is therefore:

**27.229 seconds**

against the frozen internal design target of ≤ 30 minutes.

## RPO interpretation

The last explicitly verified pre-target business state became visible 1.087882 seconds before
the requested PITR target, and the first explicitly verified post-target state occurred
1.164732 seconds after the target.

The recovered database contained the pre-target state and excluded the post-target state.

Therefore the measured business-state recovery gap for this marker experiment is bounded to:

**≤ 1.087882 seconds before the requested target**

which is within the frozen internal DB PITR RPO target of ≤ 5 minutes.

This is intentionally a marker-granularity claim. The experiment did not retain a separate
exact PostgreSQL replay-stop timestamp, so no finer-grained RPO claim is made.

## Failed attempts retained as evidence

Two bounded implementation defects were exposed before the successful restore.

### psql variable interpolation

The first marker attempt failed on the initial existence check:

`SELECT count(*) FROM programs WHERE code=:'marker_code'`

The script passed psql variable syntax through `-c`, so the server received the literal
`:'marker_code'`.

The failure occurred before INSERT, so no marker row was created.

Corrective change:

- marker SQL using psql variables is now passed through stdin;
- post-restore marker verification uses the same path;
- static CI rejects the unsafe `--set ... -c` combination.

### pgBackRest target timestamp format

The first restore attempt failed with pgBackRest error 029 because the target used an ISO
`T` separator:

`2026-09-16T10:44:13.321143+00`

pgBackRest required a space between date and time.

The failure occurred during target parsing before backup-set selection/file restore.

Corrective change:

- retained evidence timestamp remains ISO-8601;
- the restore script normalizes only the pgBackRest command input to
  `2026-09-16 10:44:13.321143+00`.

No recovery data cleanup was required after this failure because file restore had not begun.

## CI latency correction during Phase 2

The Phase 2 work exposed an unrelated CI routing inefficiency.

Run `35086854643` showed:

- `m4-infrastructure-static`: about 4 minutes 16 seconds;
- Ansible/collection installation alone: about 3 minutes 55 seconds;
- the triggering change modified only PITR restore tooling.

The baseline classifier was corrected so `scripts/restore/**` uses a lightweight
`m11-recovery-static` job instead of the full M4 infrastructure job.

Validation PR run `35087862266` completed successfully in about 7 seconds.

Actual OpenTofu/Ansible changes still use the full infrastructure validation path, and Ansible
collections are now cached by requirements hash.

## Cleanup

The temporary live marker was removed from retained `db-01` after successful PITR verification.

Cleanup result:

`M11_PITR_MARKER_CLEANUP=PASS code=M11-PITR-20260916T104401Z`

The disposable recovery VM is retained temporarily for evidence/next-step handling and remains
outside the retained Seoul runtime.

## Phase 2 conclusion

M11 Phase 2 is complete.

Verified claims:

1. the retained pgBackRest backup/WAL archive can restore PostgreSQL into a separate recovery VM;
2. time-based PITR can include a committed pre-target state while excluding a committed
   post-target state;
3. basic restored business invariants remain valid;
4. verified DB PITR RTO for this experiment is 27.229 seconds;
5. marker-granularity DB PITR RPO is bounded to ≤ 1.087882 seconds before the requested target.

Immediate next phase:

**Phase 3 — verified whole-system checkpoint backup.**
