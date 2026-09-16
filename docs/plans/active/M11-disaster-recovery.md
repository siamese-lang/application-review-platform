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

M11 Phase 3 verified the whole-system maintenance checkpoint. M11 now proceeds to full DR.

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

Status: COMPLETE

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

Status: ACTIVE

Goal: restore the verified checkpoint into newly created recovery infrastructure and prove the
business system, not only the processes, is recovered.

### Phase 4 first slice — temporary full-DR topology

Status: COMPLETE (LIVE)

Live result:

- reviewed initial plan: 23 add, 0 change, 0 destroy;
- GCP `CPUS_ALL_REGIONS` limit 12 caused two partial applies; partial state was preserved rather than cleaned up blindly;
- `recovery-db-01`, `edge-01`, `app-01`, and `obs-01` were temporarily stopped to free quota without deleting their disks or IaC definitions;
- reviewed final incremental plan: 4 add, 0 change, 0 destroy;
- `dr-edge-01`, `dr-app-01`, `dr-db-01`, and `dr-storage-01/02/03` are all RUNNING;
- retained Seoul database, Garage data disks, ops-01, and backup-01 remain intact.

Goal:

- define the recovery service topology in OpenTofu before any create/apply;
- preserve the production service boundaries required for business recovery;
- keep retained Seoul runtime and backup-01 unchanged.

Files/components:

- `infra/opentofu/variables.tf`;
- `infra/opentofu/network.tf`;
- `infra/opentofu/compute.tf`;
- `infra/opentofu/disks.tf`;
- `infra/opentofu/firewall.tf`;
- `infra/opentofu/outputs.tf`;
- focused M11 infrastructure contract test/CI wiring.

Planned recovery service topology:

- dedicated Tokyo subnet `10.70.0.0/24`;
- `dr-edge-01` — public HTTPS ingress only;
- `dr-app-01` — private Spring/application tier;
- `dr-db-01` — private PostgreSQL tier with a fresh recovery data disk;
- `dr-storage-01/02/03` — private three-node Garage tier with fresh data disks;
- retained `ops-01` remains the controller only;
- retained `backup-01` remains the backup source only;
- no duplicate observability or operations VM is required for the recovery service path.

Constraints:

- `enable_full_dr=false` by default;
- no reused Seoul service VM or persistent data disk;
- no public IP on app/db/storage nodes;
- no workload service account on temporary DR VMs;
- DR service tags/firewalls remain separate from retained service tags so production service
  traffic cannot accidentally target recovery service nodes;
- full DR requires `enable_backup=true`;
- PostgreSQL restore traffic is limited to backup-01 ↔ dr-db-01 SSH;
- Garage restore traffic is limited to backup-01 → dr-storage S3;
- application traffic is limited to dr-edge → dr-app → dr-db/dr-storage;
- Garage RPC is limited to the DR storage tier;
- existing ops-01 SSH control path may reach DR nodes through the existing managed-host SSH rule.

Verification before apply:

- exact-head OpenTofu format/validate and M11 topology contract pass;
- reviewed plan creates only the explicitly enabled temporary DR resources;
- no retained Seoul resource is changed or destroyed;
- no Phase 4 restore begins until the create plan is reviewed.

### Phase 4 second slice — DR foundation and exact checkpoint DB restore

Status: COMPLETE (LIVE)

Implementation boundary:

- use a dedicated DR inventory containing only the six DR service nodes plus `backup-01` as the delegated repository host;
- do not run the retained-runtime `site.yml` because the DR path does not require Alloy/observability for business recovery;
- prepare `dr-db-01` without `initdb` and keep PostgreSQL stopped until the checkpoint restore command;
- restore exact backup label `20260916-121314F` with immediate recovery so later archived WAL cannot move the database past the verified checkpoint boundary;
- record DB restore component timings separately from the final full-DR RTO.

Live result:

- DR foundation Ansible recap: all six DR service nodes `failed=0`, `unreachable=0`;
- exact PostgreSQL backup restored: `20260916-121314F`;
- restored database invariant checks: orphan applications 0, history/status mismatch 0, terminal-history missing 0;
- DB restore command: 10.961 seconds;
- PostgreSQL ready: 15.006 seconds from DB restore start;
- DB invariant verification complete: 16.051 seconds from DB restore start;
- result: `M11_FULL_DR_DB_RESTORE=PASS`.

These timings are DB recovery component measurements, not the full-DR RTO.

### Phase 4 third slice — verified Garage object restore

Status: COMPLETE (LIVE)

Implementation boundary:

- bootstrap only the fresh `dr-storage-01/02/03` Garage cluster;
- use the exact checkpoint object set `m11-checkpoint-20260916T121255Z`;
- require manifest SHA-256 `b6749631671f489160740c6e27c30d4aedb69e8cc80914cfc8253129ed0607c8` before upload;
- refuse a non-empty DR target bucket rather than overwrite unknown state;
- verify every source backup file by size/SHA-256 before upload;
- after upload, require the exact object-key set and re-read every restored object to verify size/SHA-256;
- retain Garage restore timing separately from final full-DR RTO.

Live result:

- first restore attempt failed before Garage mutation because the playbook lived outside `config/ansible/` and did not load shared `group_vars`; no peer/layout/bucket/key/object mutation had started;
- corrective change moved the playbook under `config/ansible/` and added a static group-variable contract;
- fresh DR Garage cluster bootstrap: PASS;
- checkpoint object count restored: 21;
- manifest SHA-256: `b6749631671f489160740c6e27c30d4aedb69e8cc80914cfc8253129ed0607c8` exact match;
- source files and restored targets both passed key/size/SHA-256 verification;
- object restore + target verification: 0.766 seconds;
- final Ansible recap: `backup-01` and all three DR storage nodes `failed=0`, `unreachable=0`;
- result: `M11_FULL_DR_OBJECT_RESTORE=PASS`.

This timing is the Garage recovery component measurement, not the full-DR RTO.

### Phase 4 fourth slice — exact application/frontend release activation

Status: COMPLETE (LIVE)

Implementation boundary:

- activate the last checkpoint-compatible release, not current repository `main`;
- exact backend/frontend release identity: `d90eb558bdb6317d49b0a7ce82148ddeb4b5babf`;
- require the retained local release bundle to pass the existing manifest/checksum verifier before transfer;
- generate inventory from `full_dr_inventory` only;
- reuse the existing M6 `release.yml` activation mechanics so Flyway privilege remains temporary and bounded;
- delegate migration work to `dr-db-01` through the DR `db` group;
- activate frontend only after backend readiness succeeds;
- do not target retained Seoul app/edge/db nodes.

Live result:

- retained bundle `d90eb558bdb6317d49b0a7ce82148ddeb4b5babf` passed the existing release manifest/checksum verifier on ops-01;
- DR release activation completed with `dr-app-01` `failed=0/unreachable=0` and `dr-edge-01` `failed=0/unreachable=0`;
- backend activation readiness passed before frontend activation;
- result: `M11_DR_RELEASE_RC=0`.

### Phase 4 fifth slice — public HTTPS recovery boundary

Status: ACTIVE

Implementation boundary:

- bootstrap a Let's Encrypt short-lived IP certificate for the temporary `dr-edge-01` public address;
- use `full_dr` / `full_dr_inventory` outputs only;
- reconcile only the DR edge role after certificate installation;
- keep normal TLS verification enabled and never use `curl -k` / `--insecure`;
- require a successful public HTTPS programs API request before the representative business smoke.

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

Execute **Phase 4 — full DR rebuild and business recovery**.

Phase 3 whole-system checkpoint is complete and retained in:

`docs/operations/M11_PHASE3_CHECKPOINT_EVIDENCE.md`

Verified Phase 3 recovery source:

- checkpoint ID: `m11-checkpoint-20260916T121255Z`;
- PostgreSQL full backup: `20260916-121314F`;
- backup start/stop WAL segment: `000000010000000200000087`;
- Garage object count: 21;
- Garage manifest SHA-256:
  `b6749631671f489160740c6e27c30d4aedb69e8cc80914cfc8253129ed0607c8`;
- frozen start → complete backup verification: 76.718 seconds;
- frozen start → writes resumed: 98.711 seconds;
- post-resume representative HTTPS business smoke: PASS.

The temporary full-DR topology, exact checkpoint database restore, matching Garage object restore, and exact release activation are now live-verified.
The immediate next work is establishing the DR public HTTPS boundary before final business/integrity verification.

Phase 4 must:

1. configure the six recovery service nodes through the dedicated repository-owned DR automation;
2. restore PostgreSQL from `20260916-121314F` without replaying later WAL beyond the checkpoint boundary;
3. restore Garage objects from the matching checkpoint manifest;
4. activate the intended application/frontend release against only the recovery data path;
5. verify business and attachment invariants;
6. run representative HTTPS workflow against the recovered environment;
7. measure checkpoint age/effective RPO and full DR RTO.

Do not restore into the retained Seoul runtime.
Do not change the frozen backup architecture.
