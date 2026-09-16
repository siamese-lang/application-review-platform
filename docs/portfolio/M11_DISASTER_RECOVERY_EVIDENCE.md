# Evidence Card — Recover business state, not just processes

Status: FINAL
Milestone: M11
Evidence maturity: E5
Source release SHA: `d90eb558bdb6317d49b0a7ce82148ddeb4b5babf`

## Context / assumption

The application persists business state in PostgreSQL and attachment bytes in a three-node
Garage object store. A successful service restart or healthy replica set does not prove that
both stores can be recovered to a coherent business state after data loss.

The frozen recovery design therefore required independent PostgreSQL PITR plus a verified
whole-system checkpoint for the database/object-store boundary.

## Problem

Before M11, the project had backup architecture and runtime resilience evidence, but no proof
that:

- PostgreSQL could be restored to a requested point in time;
- pre-target state would be retained while post-target state was excluded;
- database metadata and attachment objects could be restored together into separate
  infrastructure;
- the recovered application would preserve workflow, history, audit, ownership, and attachment
  integrity.

Process health alone could not answer those questions.

## Baseline

Environment:

- retained Seoul application runtime;
- PostgreSQL single primary;
- Garage three-node replication;
- synthetic application/reviewer data only;
- temporary backup/PITR/full-DR resources placed in Tokyo under ADR-004.

Independent DB PITR experiment:

- backup: `20260916-090503F`;
- target: `2026-09-16T10:44:13.321143+00`;
- PRE visible 1.087882 seconds before target;
- POST visible 1.164732 seconds after target.

Whole-system checkpoint:

- ID: `m11-checkpoint-20260916T121255Z`;
- PostgreSQL backup: `20260916-121314F`;
- object manifest: 21 objects;
- manifest SHA-256:
  `b6749631671f489160740c6e27c30d4aedb69e8cc80914cfc8253129ed0607c8`;
- attachment lifecycle at checkpoint: 17 AVAILABLE / 0 PENDING / 0 DELETE_PENDING / 0 FAILED.

## Analysis

The recovery problem was separated into two evidence questions.

First, PostgreSQL PITR was tested independently so database recovery timing and point-in-time
semantics were not obscured by application or object-store rebuild work.

Second, PostgreSQL and Garage were treated as separate stores with no distributed transaction.
Instead of pretending they shared one snapshot, writes and background reconciliation were
bounded during a maintenance checkpoint, then both backup sets were verified before writes
resumed.

The full DR drill then used only new recovery service VMs and fresh DB/Garage disks, avoiding
a false success caused by reusing retained Seoul service data.

## Options considered

1. Restart existing Seoul services and call that recovery.
   - Rejected because it proves availability after restart, not backup recoverability.

2. Restore only PostgreSQL.
   - Rejected because AVAILABLE attachment metadata without matching object bytes would not
     prove application-level recovery.

3. Treat Garage replication as backup.
   - Rejected because replication and independent backup have different failure boundaries.

4. Add PostgreSQL HA, a managed database, or another backup product.
   - Rejected as outside the measured recovery question and the frozen architecture.

5. Use independent PITR plus an explicit cross-store maintenance checkpoint and rebuild into
   separate temporary infrastructure.
   - Accepted because it directly tests the existing recovery design with bounded complexity.

## Decision / action

M11 implemented and executed:

- pgBackRest full backup plus WAL archive;
- independent PostgreSQL PITR to a disposable recovery VM;
- mutation-gated PostgreSQL/Garage maintenance checkpoint;
- independent Garage object backup with key/size/SHA-256 manifest;
- repository-managed temporary full-DR edge/app/db/Garage topology;
- exact checkpoint DB/object restore;
- exact checkpoint-compatible release activation;
- normal-TLS HTTPS business smoke;
- repository-owned restored-state integrity verification.

No new HA architecture was introduced.

## Verification

PostgreSQL PITR:

- PRE state included: PASS;
- POST state excluded: PASS;
- orphan applications: 0;
- history/status mismatch: 0;
- terminal-history missing: 0;
- DB PITR RTO: **27.229 seconds**;
- marker-granularity recovery gap: **≤ 1.087882 seconds**.

These met the frozen internal DB RTO ≤30 minutes and RPO ≤5 minutes targets.

Full DR:

- exact checkpoint database restored;
- 21 checkpoint objects restored and key/size/SHA-256 verified;
- HTTPS applicant/reviewer workflow passed;
- final smoke application 10412 reached APPROVED with required history;
- reviewer/state/history/audit mismatches: 0;
- 17 DB-referenced checkpoint attachments matched manifest and restored Garage contents;
- PENDING/FAILED/DELETE_PENDING at restored checkpoint: 0/0/0;
- `M11_FULL_DR_INTEGRITY=PASS`.

Closeout:

- temporary-resource plan: 0 add / 0 change / 35 destroy;
- 35 temporary resources destroyed;
- retained Seoul runtime restored;
- stale WAL-archive wiring discovered after backup teardown and removed through a
  repository-owned cleanup;
- final archive state: `off|(disabled)`;
- final retained service path: PASS;
- final persistent OpenTofu plan: no changes.

## Trade-off / limit

The drill did not retain one authoritative end-to-end full-DR recovery start and business-ready
completion boundary. Therefore no full-DR RTO is claimed.

It also did not retain one simulated-disaster timestamp from which an effective full-system RPO
could be calculated. The DB component has measured PITR RPO/RTO evidence; the whole-system
checkpoint has maintenance-window timings, but those values are not substituted for full-DR
RPO/RTO.

The design still has a single PostgreSQL primary and does not provide automatic failover or
continuous multi-region availability. Simultaneous loss of the primary region and the single
backup repository remains outside the claim boundary.

The DR exercise also encountered GCP CPU quota and required temporarily stopping retained
Seoul edge/app/observability VMs before creating the full recovery topology.

## Repository evidence

- code/config:
  - `infra/opentofu/`
  - `config/ansible/backup.yml`
  - `config/ansible/full-dr-foundation.yml`
  - `config/ansible/full-dr-garage-restore.yml`
  - `config/ansible/full-dr-integrity.yml`
  - `config/ansible/m11-backup-closeout.yml`
  - `deploy/closeout-m11-backup.sh`
- migration:
  - none; M11 did not change the application schema to create a recovery story
- focused tests:
  - `scripts/deploy/test-m11-backup-foundation.py`
  - `scripts/deploy/test-m11-pitr-execution.py`
  - `scripts/deploy/test-m11-full-dr-foundation.py`
  - `scripts/deploy/test-m11-full-dr-garage-restore.py`
  - `scripts/deploy/test-m11-full-dr-integrity.py`
  - `scripts/deploy/test-m11-backup-closeout.py`
- workload/experiment:
  - Phase 2 PostgreSQL PITR marker experiment
  - Phase 3 checkpoint `m11-checkpoint-20260916T121255Z`
  - Phase 4 independent full-DR rebuild
- CI:
  - M11 implementation/closeout exact-head and post-merge baseline CI retained in phase evidence
- runtime evidence:
  - `docs/operations/M11_PHASE1_BACKUP_FOUNDATION_EVIDENCE.md`
  - `docs/operations/M11_PHASE2_PITR_EVIDENCE.md`
  - `docs/operations/M11_PHASE3_CHECKPOINT_EVIDENCE.md`
  - `docs/operations/M11_PHASE4_FULL_DR_EVIDENCE.md`
  - `docs/operations/M11_PHASE5_RESIDUAL_DECISION_EVIDENCE.md`
  - `docs/operations/M11_PHASE6_CLOSEOUT_EVIDENCE.md`

## Portfolio claim

Verified PostgreSQL point-in-time recovery and a separate full-system rebuild from a
PostgreSQL/Garage checkpoint: the DB PITR experiment recovered the intended pre-target state
with 27.229-second RTO and ≤1.087882-second marker recovery gap, while the rebuilt application
passed HTTPS workflow plus history/audit/attachment SHA-256 integrity checks; end-to-end
full-DR RTO remains explicitly unclaimed.
