# M11 Phase 4 Full DR Recovery Evidence

Status: VERIFIED LIVE  
Milestone: M11 Disaster Recovery  
Evidence date: 2026-09-16 UTC  
Recovery implementation main SHA at integrity verification: `6b964f62fdc2c606446865d4bcdace8defc56de6`

## Scope

Phase 4 rebuilt the application service path in a separate Tokyo recovery environment from the
verified Phase 3 checkpoint and proved that the recovered business system, database state, and
checkpoint attachment metadata remained consistent.

This evidence covers:

- repository-defined temporary recovery infrastructure;
- exact checkpoint PostgreSQL restore;
- exact checkpoint Garage object restore;
- checkpoint-compatible backend/frontend release activation;
- public HTTPS recovery;
- representative applicant/reviewer business flow;
- restored reviewer/history/audit ownership invariants;
- checkpoint DB ↔ manifest ↔ restored Garage attachment integrity.

This evidence does not claim:

- PostgreSQL automatic failover;
- multi-region HA;
- survival of simultaneous loss of Seoul and the single backup-01 repository;
- a measured full-DR RTO or an achieved RTO ≤ 60 minutes.

The full recovery exercise did not retain one authoritative start timestamp and one
business-ready end timestamp across the quota interruption and bounded corrective changes.
Component timings are retained separately and are not summed into a synthetic full-DR RTO.

## Recovery source identity

Verified Phase 3 checkpoint:

- checkpoint ID: `m11-checkpoint-20260916T121255Z`;
- frozen checkpoint boundary: `2026-09-16T12:13:11.077Z`;
- PostgreSQL full backup: `20260916-121314F`;
- backup start/stop WAL segment: `000000010000000200000087`;
- Garage manifest object count: 21;
- Garage manifest SHA-256:
  `b6749631671f489160740c6e27c30d4aedb69e8cc80914cfc8253129ed0607c8`;
- checkpoint AVAILABLE attachment rows: 17;
- application/frontend release:
  `d90eb558bdb6317d49b0a7ce82148ddeb4b5babf`.

The current repository main was not substituted for the checkpoint-compatible application
release.

## Temporary recovery topology

Dedicated Tokyo DR subnet:

`10.70.0.0/24`

Recovery service nodes:

- `dr-edge-01` — `10.70.0.10`;
- `dr-app-01` — `10.70.0.20`;
- `dr-db-01` — `10.70.0.30`;
- `dr-storage-01` — `10.70.0.41`;
- `dr-storage-02` — `10.70.0.42`;
- `dr-storage-03` — `10.70.0.43`.

Retained control/backup nodes:

- `ops-01` — `10.40.0.50`;
- `backup-01` — `10.60.0.10`.

Initial reviewed OpenTofu plan:

`23 add / 0 change / 0 destroy`

The GCP `CPUS_ALL_REGIONS` quota was observed at usage 12 / limit 12 during the build. Two
partial applies were preserved rather than discarded. To release CPU quota without deleting
persistent resources, the following retained VMs were stopped:

- `edge-01`;
- `app-01`;
- `obs-01`;
- `recovery-db-01`.

After quota was freed, the final reviewed incremental plan was:

`4 add / 0 change / 0 destroy`

All six DR service VMs then reached RUNNING state. Retained Seoul database/storage disks,
`ops-01`, and `backup-01` were not used as restore targets.

## PostgreSQL exact checkpoint restore

Restore source:

`20260916-121314F`

The restore used immediate recovery with promotion so archived WAL after the checkpoint could
not move the recovered database beyond the intended boundary.

Live result:

- orphan applications: 0;
- application/latest-history status mismatch: 0;
- terminal applications missing terminal history: 0;
- restore command: **10.961 seconds**;
- PostgreSQL ready: **15.006 seconds** from restore start;
- initial DB invariant verification complete: **16.051 seconds** from restore start;
- result: `M11_FULL_DR_DB_RESTORE=PASS`.

These are PostgreSQL component timings, not full-DR RTO.

## Garage exact checkpoint restore

The fresh three-node DR Garage cluster was initialized only on
`dr-storage-01/02/03`.

The first restore attempt failed before Garage mutation because the restore playbook was outside
`config/ansible/` and did not load shared `group_vars`. No peer/layout/bucket/key/object
mutation had started. The playbook was moved into the repository Ansible path and a static
contract was added.

Successful restore result:

- exact checkpoint manifest SHA-256 matched;
- 21 checkpoint objects restored;
- every source backup file passed size/SHA-256 verification before upload;
- restored target key set matched the manifest;
- every restored checkpoint object passed target size/SHA-256 re-read verification;
- restore + target verification: **0.766 seconds**;
- final Ansible hosts: failed=0, unreachable=0;
- result: `M11_FULL_DR_OBJECT_RESTORE=PASS`.

This is a Garage component timing, not full-DR RTO.

## Exact application/frontend release activation

Retained release bundle:

`/srv/arp/releases/incoming/d90eb558bdb6317d49b0a7ce82148ddeb4b5babf`

The existing immutable release verifier passed before transfer.

Activation result:

- `dr-app-01`: failed=0, unreachable=0;
- `dr-edge-01`: failed=0, unreachable=0;
- backend readiness passed before frontend activation;
- Flyway migration privilege remained bounded through the existing release path;
- result: `M11_DR_RELEASE_RC=0`.

## Public HTTPS recovery boundary

Temporary DR public URL:

`https://34.146.142.122`

A Let's Encrypt short-lived IP certificate was bootstrapped only for the DR edge. Normal TLS
verification was kept enabled; `curl -k` / `--insecure` was not used.

Public programs API verification passed:

`M11_FULL_DR_HTTPS=PASS`

The repository implementation for this boundary was merged through PR #162. Exact PR head
`38fccc15f14c61cc75fe51e648587343166ab3d7` passed baseline CI run
`35108023664`.

## Representative recovered business flow

The existing `deploy/cloud-smoke.sh` ran against the recovered public HTTPS environment and
passed the complete representative workflow:

- SPA root and deep link;
- public programs API;
- applicant registration;
- login/session/CSRF;
- structured application create/edit;
- attachment upload;
- applicant attachment SHA-256 download verification;
- submit;
- reviewer login;
- review start;
- reviewer attachment SHA-256 verification;
- approve;
- final APPROVED state;
- required status history.

Final result:

`PASS: HTTPS SPA/API, registration/session/CSRF, application edit/submit, Garage attachment SHA-256 integrity, reviewer start/approve, and final history (application 10412).`

The workflow created one new attachment after the checkpoint. It is intentionally not treated
as checkpoint data in the restored checkpoint integrity verification.

## Restored checkpoint full integrity verification

Repository-owned integrity automation was merged through PR #163.

Final implementation head:

`6e68b320b4bee3c84244a9588ec0bf5ef5d2b733`

Exact-head baseline CI:

`35113214792` — SUCCESS

Post-merge main:

`6b964f62fdc2c606446865d4bcdace8defc56de6`

Post-merge baseline CI:

`35113354947` — SUCCESS

The live integrity verifier used the Phase 3 frozen checkpoint cutoff
`2026-09-16T12:13:11.077Z`, so later recovery-smoke data was reported separately instead of
being mistaken for checkpoint state.

Live result:

```text
M11_FULL_DR_REVIEWER_STATE_MISMATCH=0
M11_FULL_DR_REVIEWER_HISTORY_OWNERSHIP_MISMATCH=0
M11_FULL_DR_HISTORY_TRANSITION_MISMATCH=0
M11_FULL_DR_HISTORY_CHAIN_MISMATCH=0
M11_FULL_DR_AUDIT_SUBJECT_MISMATCH=0
M11_FULL_DR_AUDIT_ACTOR_OWNERSHIP_MISMATCH=0
M11_FULL_DR_CHECKPOINT_ATTACHMENT_UPLOADER_MISMATCH=0
M11_FULL_DR_CHECKPOINT_PENDING_ATTACHMENTS=0
M11_FULL_DR_CHECKPOINT_FAILED_ATTACHMENTS=0
M11_FULL_DR_CHECKPOINT_DELETE_PENDING_ATTACHMENTS=0
M11_FULL_DR_POST_CHECKPOINT_ATTACHMENT_ROWS=1
M11_FULL_DR_CHECKPOINT_AVAILABLE_ATTACHMENTS=17
M11_FULL_DR_CHECKPOINT_MANIFEST_OBJECTS=21
M11_FULL_DR_CHECKPOINT_ATTACHMENT_OBJECTS_VERIFIED=17
M11_FULL_DR_TARGET_OBJECTS_CURRENT=22
M11_FULL_DR_TARGET_OBJECTS_NOT_IN_CHECKPOINT_MANIFEST=1
M11_FULL_DR_MANIFEST_SHA256=b6749631671f489160740c6e27c30d4aedb69e8cc80914cfc8253129ed0607c8
M11_FULL_DR_INTEGRITY=PASS
```

Ansible recap:

- `backup-01`: failed=0, unreachable=0;
- `dr-db-01`: failed=0, unreachable=0.

Interpretation:

- all remaining reviewer/state ownership invariants passed;
- all checked history transition/chain invariants passed;
- audit subject and actor ownership invariants passed;
- no checkpoint `PENDING`, `FAILED`, or `DELETE_PENDING` attachment was hidden;
- all 17 checkpoint AVAILABLE attachment DB rows matched manifest key/size/SHA-256;
- all 17 DB-referenced checkpoint attachment objects were re-read from recovered Garage and
  matched their recorded size/SHA-256;
- the manifest still contains 21 checkpoint objects because not every retained object is an
  AVAILABLE attachment row;
- the current DR bucket contains 22 objects, exactly one more than the checkpoint manifest;
- one post-checkpoint attachment row and one non-checkpoint target object correspond to the
  representative recovery smoke and are not a checkpoint-integrity failure.

## Timing and recovery claims

Measured component timings retained by Phase 4:

- PostgreSQL restore command: **10.961 seconds**;
- PostgreSQL ready: **15.006 seconds**;
- PostgreSQL initial invariant verification complete: **16.051 seconds**;
- Garage restore + complete 21-object target verification: **0.766 seconds**.

Phase 3 checkpoint maintenance measurements remain:

- frozen start → backup-set verification: **76.718 seconds**;
- frozen start → writes resumed: **98.711 seconds**.

No full-DR RTO is claimed.

The exercise included:

- initial IaC apply;
- global CPU quota failure;
- retained VM stops to free quota;
- partial apply continuation;
- DR foundation;
- DB restore;
- Garage playbook-path defect correction;
- Garage restore;
- exact release activation;
- DR TLS bootstrap;
- business smoke;
- final restored checkpoint integrity verification.

Those component/event durations must not be added together and labeled as RTO. A reliable
full-DR RTO requires a clearly defined recovery start and business-ready end from a single
timed recovery run or equivalent authoritative timestamps.

Likewise, the exact checkpoint recovery boundary is proven, but an effective full-system RPO
relative to a specific simulated disaster time was not measured in this exercise. No
full-system RPO target claim is made.

## Phase 4 conclusion

Phase 4 is complete from the recovery correctness and business-readiness perspective.

Verified claims:

1. the full application service path can be rebuilt on separate repository-defined recovery VMs;
2. PostgreSQL can be restored to the exact verified checkpoint backup without replaying later WAL;
3. the matching independent Garage checkpoint can be restored and cryptographically verified;
4. the exact checkpoint-compatible application/frontend release can be activated against the
   recovered data path;
5. the temporary DR environment serves valid public HTTPS without weakening TLS verification;
6. the representative applicant/reviewer business workflow succeeds on the recovered system;
7. reviewer/state ownership, history transition/chain, and audit subject/actor invariants hold;
8. all 17 checkpoint AVAILABLE attachment rows match the retained manifest and recovered Garage
   objects by key, size, and SHA-256;
9. post-checkpoint smoke data remains distinguishable from the restored checkpoint dataset.

Retained limitation:

- full-DR RTO and effective full-system RPO are not claimed because the exercise did not retain
  authoritative end-to-end timing boundaries for those measurements.

Immediate next work:

**Phase 5 — residual recovery decision.**

Use the retained Phase 2 and Phase 4 evidence to decide whether any bounded corrective recovery
change is justified. Do not repeat successful restore/business/integrity paths unless a specific
correction requires it.
