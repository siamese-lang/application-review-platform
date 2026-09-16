# M11 Disaster Recovery — Execution Plan

Status: ACTIVE
Planning base: `4030e35ee1c90a4a006dd843ba8502b754bc0ce5`

## Goal

Implement and verify the frozen backup/recovery design with measured recovery evidence.

M11 is successful when the repository and retained runtime evidence can answer:

> From a known backup/checkpoint, can PostgreSQL and attachment objects be restored into a
> separate recovery environment, within measured recovery windows, with the application
> business state and attachment integrity verified afterward?

M11 is not a database-HA milestone and is not a multi-region-HA redesign.

The evidence chain is:

`backup identity → fault/recovery target → restore into separate environment → measured
RPO/RTO → business invariants → attachment size/SHA-256 verification → cleanup/no-drift`

## Frozen baseline

M11 implements the existing M0 backup/recovery design; it does not replace it.

Required baseline:

- PostgreSQL backup/restore/PITR uses pgBackRest;
- WAL archiving is enabled and verified;
- database PITR is tested independently from full-system DR;
- internal design target, not an achieved claim:
  - DB PITR RPO ≤ 5 minutes;
  - DB PITR RTO ≤ 30 minutes;
- Garage replication is not treated as backup;
- `backup-01` holds an independent object backup plus a manifest containing:
  - object key;
  - size;
  - SHA-256;
  - backup timestamp;
- whole-system DR uses a verified maintenance checkpoint because PostgreSQL and Garage do not
  share a distributed transaction or common point-in-time snapshot;
- full DR rebuilds new VMs using IaC/configuration and restores data into that separate
  environment before business verification;
- whole-region loss combined with loss of the single `backup-01` repository remains outside
  the project claim boundary.

No ADR is required to implement this frozen architecture. Any change to the backup
architecture itself requires an ADR before implementation.

## Entry state

M1–M10 are complete.

Current retained Seoul runtime:

- edge-01;
- app-01;
- db-01;
- storage-01;
- storage-02;
- storage-03;
- ops-01;
- obs-01.

Current persistent runtime plan after M10 closeout:

`No changes. Your infrastructure matches the configuration.`

Retained storage-03 overrides:

- machine type: `e2-small`;
- boot disk type: `pd-standard`.

Temporary M10 loadgen infrastructure has been destroyed.

Current repository backup/restore implementation state:

- optional `backup-01` IaC and Ansible role are implemented and live-verified;
- pgBackRest remote repository configuration is installed;
- PostgreSQL WAL archiving is enabled and live-verified;
- a full backup `20260916-090503F` completed successfully;
- Garage object-backup tooling and manifest verification are implemented;
- retained Phase 1 evidence:
  `docs/operations/M11_PHASE1_BACKUP_FOUNDATION_EVIDENCE.md`;
- disposable `recovery-db-01` is implemented and live-verified;
- independent PostgreSQL PITR completed successfully from backup `20260916-090503F`;
- verified PITR RTO: 27.229 seconds;
- marker-granularity recovery gap: ≤ 1.087882 seconds before the requested target;
- retained Phase 2 evidence:
  `docs/operations/M11_PHASE2_PITR_EVIDENCE.md`.

M11 now proceeds to the verified whole-system checkpoint/full DR phases.

## Guardrails

- synthetic data only;
- never destroy or corrupt the retained production-like Seoul runtime merely to make the DR
  scenario dramatic;
- restore/PITR verification uses separate disposable recovery VMs by default;
- no PostgreSQL automatic failover;
- no Cloud SQL or managed application service;
- no new primary database or object-storage product;
- no second backup product solely for résumé value;
- no claim of RPO/RTO before measured evidence exists;
- do not call a PostgreSQL process start a successful recovery until business/data checks pass;
- do not call Garage replication a backup;
- do not claim the earlier M10 FAILED rows are automatically repaired;
- preserve exact backup identity, source release SHA, dataset/checkpoint identity, timestamps,
  target recovery time, restore logs, and verification output;
- retain unexpected restore inconsistencies before repair;
- all infrastructure create/destroy plans must be reviewed before apply;
- final temporary recovery infrastructure must be destroyed unless a later milestone explicitly
  requires handoff;
- final persistent Seoul runtime must return to no-drift.

## Recovery infrastructure model

ADR-004 permits temporary experiment/recovery resources outside Seoul when quota/capacity
requires it, with Tokyo preferred.

M11 may therefore introduce repository-managed temporary recovery resources such as:

- `backup-01`;
- a temporary PostgreSQL PITR verification VM;
- temporary full-DR application/database/object-storage/edge resources as required by the
  frozen role boundaries.

The exact temporary topology, subnet, disk sizes, and machine types must be justified by a
reviewed OpenTofu plan before apply.

Do not silently collapse the full DR exercise into the original live VMs.

## Phase 1 — backup/recovery foundation

Status: COMPLETE

Goal: create the minimum repository-owned infrastructure and automation needed to produce a
verified backup set before any recovery drill.

Expected implementation:

1. add optional temporary `backup-01` infrastructure through OpenTofu;
2. add inventory/Ansible support for the backup role without changing persistent runtime
   behavior when disabled;
3. install/configure pgBackRest using the frozen PostgreSQL 16 runtime;
4. configure PostgreSQL WAL archiving to the backup repository;
5. establish repository ownership/permissions so backup data is not application-accessible by
   default;
6. add repository-owned backup verification commands/scripts;
7. add object-backup tooling that copies Garage objects to the independent backup repository;
8. generate a deterministic manifest with object key, size, SHA-256, and backup timestamp;
9. add focused static/contract tests and CI coverage.

Phase 1 verification:

- reviewed OpenTofu plan contains only intended temporary backup infrastructure changes;
- Ansible apply has failed=0/unreachable=0;
- pgBackRest stanza/check succeeds;
- a PostgreSQL full backup completes and is listed by pgBackRest;
- WAL archiving is observed after the backup;
- object backup completes;
- manifest validation succeeds;
- selected source objects match backup size/SHA-256;
- no Seoul runtime replacement/destruction is planned;
- exact-head CI passes.

Do not execute PITR until this healthy backup foundation is proven.

## Phase 2 — independent PostgreSQL PITR experiment

Status: COMPLETE

Goal: measure whether a PostgreSQL point-in-time restore can recover a known synthetic
business state into a separate recovery database environment.

Experiment requirements:

1. start from a verified pgBackRest backup/WAL archive;
2. record exact source DB state and synthetic marker transactions;
3. create at least two distinguishable committed states around the intended PITR target;
4. record target timestamp and transaction evidence before any destructive test mutation;
5. create/use a separate disposable PostgreSQL recovery VM;
6. restore the backup and replay WAL to the chosen target;
7. measure:
   - backup point / target point;
   - actual recovered point;
   - restore start;
   - PostgreSQL ready;
   - business/data verification complete;
8. verify the recovered database contains the expected pre-target state and excludes the
   intended post-target state;
9. verify retained business invariants against the restored DB;
10. retain pgBackRest restore/recovery evidence.

Primary measurements:

- measured DB PITR RPO;
- measured DB PITR RTO.

The design target RPO ≤ 5 minutes / RTO ≤ 30 minutes becomes a project claim only if this
experiment actually meets it.

Do not overwrite the retained db-01 solely to exercise PITR.

## Phase 3 — verified whole-system checkpoint backup

Status: NEXT

Goal: create one DB/object backup set with an explicit cross-store consistency boundary.

The checkpoint must follow the frozen sequence:

1. block new mutations temporarily;
2. let in-flight mutations finish;
3. verify attachment `PENDING` count is zero;
4. create the PostgreSQL checkpoint backup;
5. copy Garage objects to backup-01;
6. generate the object manifest;
7. verify the complete backup set;
8. resume writes.

Required evidence:

- exact checkpoint start/end;
- mutation-block mechanism and proof it was removed;
- in-flight/PENDING checks;
- pgBackRest backup label/identity;
- WAL/archive state;
- object count;
- manifest SHA-256;
- per-object key/size/SHA-256 data;
- backup verification result;
- representative business smoke after writes resume.

If the checkpoint cannot be made consistent, retain the inconsistency and fix the cause before
attempting full DR.

## Phase 4 — full DR rebuild and business recovery

Status: PLANNED

Goal: restore the verified checkpoint into newly created recovery infrastructure and prove the
business system, not only the processes, is recovered.

Required sequence:

1. create the reviewed temporary DR topology through IaC;
2. configure the nodes through the repository Ansible path;
3. restore PostgreSQL from the checkpoint backup;
4. restore Garage objects from the independent object backup;
5. deploy/activate the exact intended application/frontend release;
6. configure the recovered runtime to use only the restored recovery data path;
7. run automated business/integrity checks;
8. run the representative HTTPS workflow against the recovered environment;
9. measure restore/recovery timing from a clearly defined start to business-ready verification.

Required business verification:

- application status matches latest history;
- no orphan applications;
- reviewer/state ownership invariants hold;
- audit/history subject invariants hold;
- every `AVAILABLE` attachment exists in restored object storage;
- restored attachment size and SHA-256 match metadata/manifest;
- no unexpected `PENDING`, `FAILED`, or `DELETE_PENDING` state is hidden;
- terminal applications have terminal history;
- representative applicant/reviewer workflow succeeds.

Primary measurements:

- full checkpoint age / effective RPO;
- measured full DR RTO.

Internal design target RTO ≤ 60 minutes becomes a claim only if measured.

## Phase 5 — residual recovery decision

Status: PLANNED

After PITR and full DR evidence:

- compare observed RPO/RTO and failure points with the frozen targets;
- identify at most one bounded corrective change only if recovery evidence justifies it;
- re-run only the affected recovery path after a corrective change;
- do not add HA or another backup platform to make the result look stronger;
- retain negative results and unresolved limitations explicitly.

A result outside the design target is valid evidence when the cause and trade-off are
documented.

## Phase 6 — M11 closeout

Status: PLANNED

Required closeout:

- sanitized M11 backup/recovery evidence;
- exact backup/checkpoint/restore/source/release identities;
- DB PITR measured RPO/RTO;
- full DR measured RPO/RTO;
- restored business/attachment integrity evidence;
- explicit unresolved limitations;
- Evidence Map update;
- Evidence Card only if the recovery story reaches the required maturity;
- R5 from M10 formally satisfied or retained as unresolved based on actual evidence;
- temporary recovery infrastructure removed;
- final persistent Seoul runtime no-drift;
- active M11 plan moved to completed;
- exact-head and post-merge main CI successful.

## Expected repository areas

Likely M11 implementation areas:

- `infra/opentofu/` — optional temporary backup/DR resources;
- `config/ansible/` — backup/recovery roles;
- `scripts/backup/` — pgBackRest/checkpoint/object-backup tooling;
- `scripts/restore/` — PITR/full-DR restore tooling;
- `docs/operations/BACKUP_RECOVERY.md` only if implementation details can be added without
  changing the frozen design;
- `docs/operations/M11_*.md` — measured evidence;
- `docs/portfolio/PORTFOLIO_EVIDENCE_MAP.md`;
- `docs/portfolio/` evidence card only if warranted.

## Immediate next work

Execute **Phase 3 — verified whole-system checkpoint backup**.

Phase 2 independent PITR is complete and retained in:

`docs/operations/M11_PHASE2_PITR_EVIDENCE.md`

Measured Phase 2 result:

- target: `2026-09-16T10:44:13.321143+00`;
- recovered marker state: PRE included / POST excluded;
- verified DB PITR RTO: 27.229 seconds;
- marker-granularity recovery gap: ≤ 1.087882 seconds before the requested target.

The next slice must implement only the frozen cross-store checkpoint sequence:

1. block new mutations temporarily;
2. let in-flight mutations finish;
3. verify attachment `PENDING` count is zero;
4. create the PostgreSQL checkpoint backup;
5. copy Garage objects to `backup-01`;
6. generate and verify the object manifest;
7. retain exact checkpoint/backup identities;
8. resume writes and prove the mutation block was removed;
9. run representative business smoke after writes resume.

Do not start full-system DR until the checkpoint backup is independently verified.
Do not change the frozen backup architecture.
