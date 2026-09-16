# M11 Phase 1 Backup Foundation Evidence

Status: VERIFIED LIVE
Milestone: M11 Disaster Recovery
Evidence date: 2026-09-16 UTC
Source main SHA at verification: `1268c7c8a2e51019b08b5acc4a18db3ac07259d4`

## Scope

Phase 1 established the frozen backup foundation without replacing or destroying the retained
Seoul runtime.

Verified boundaries:

- temporary `backup-01` in Tokyo with no public IP and no attached service account;
- independent 100 GB `pd-standard` backup disk;
- pgBackRest repository on `backup-01`;
- PostgreSQL 16 WAL archiving from `db-01`;
- independent Garage object copy plus manifest on the backup disk;
- static/contract CI for the repository implementation.

PITR and full DR are not claimed by this evidence. They remain later M11 phases.

## Infrastructure apply

Reviewed OpenTofu plan:

- 8 create;
- 0 change;
- 0 destroy.

Applied result:

- 8 added;
- 0 changed;
- 0 destroyed.

Verified `backup-01`:

- status: RUNNING;
- private IP: `10.60.0.10`;
- zone: `asia-northeast1-a`;
- no external access configuration;
- no service account;
- independent disk visible as `/dev/disk/by-id/google-arp-backup-data`;
- attached data disk size: 100 GB;
- OS Login SSH/Ansible ping: PASS.

The retained Seoul nodes were not replaced or destroyed.

## Ansible foundation apply

Final successful play recap:

- `backup-01`: ok=23, changed=6, unreachable=0, failed=0;
- `db-01`: ok=16, changed=11, unreachable=0, failed=0.

The final apply established:

- pgBackRest repository and database configuration;
- bidirectional restricted SSH path required by the remote repository model;
- PostgreSQL WAL archiving;
- repository/object-backup tooling;
- pgBackRest stanza/check validation.

Three runtime prerequisites were exposed and fixed before the successful apply:

- install `acl` so Ansible can safely become the unprivileged service users;
- normalize `/var/lib/pgbackrest` ownership for the repository service account;
- create `/etc/pgbackrest` explicitly before templating configuration.

These fixes did not alter the frozen backup architecture.

## PostgreSQL full backup

Verified full backup:

- result: `M11_FULL_BACKUP=PASS`;
- backup label: `20260916-090503F`;
- backup start: `2026-09-16 09:05:03+00`;
- backup stop: `2026-09-16 09:06:05+00`;
- database size: 381.3 MB;
- repository backup-set size: 54.2 MB;
- file total: 1,358;
- backup WAL start: `000000010000000200000079`;
- backup WAL stop: `00000001000000020000007A`;
- pgBackRest stanza status: `ok`.

The backup completed only after the required WAL segments were archived.

## WAL archive verification

A post-backup WAL switch/check was executed independently of the backup completion.

Observed:

- forced switch returned LSN `2/7B000078`;
- pgBackRest check: PASS;
- WAL segment `00000001000000020000007C` was reported successfully archived to repo1;
- repository WAL archive range advanced from max `...7A` to max `...7C`;
- retained result: `M11_WAL_ARCHIVE_CHECK=PASS`;
- stanza status remained `ok`.

This verifies that WAL archiving continued after the full backup.

## Garage object backup and manifest

Retained object-backup run:

`m11-phase1-20260916T090953Z`

The backup copied the Garage bucket into the independent backup disk and generated a manifest
containing object key, backup file, size, SHA-256, and backup timestamp.

Independent verifier result:

- `M11_OBJECT_BACKUP_VERIFY=PASS`;
- object count: 21;
- manifest SHA-256:
  `42ab06b602af75011bf081ae642d8b2308a0cbb531a324e8c5bef4267f083893`.

The verifier re-read every retained backup file and checked:

- manifest object count;
- duplicate object keys;
- backup path containment;
- file existence;
- file size;
- SHA-256;
- backup timestamp presence.

## CI

Repository head used for the final Phase 1 live run:

`1268c7c8a2e51019b08b5acc4a18db3ac07259d4`

Post-merge `baseline-ci` run:

- run: `35075938819`;
- conclusion: SUCCESS.

## Phase 1 conclusion

M11 Phase 1 is complete.

Verified backup foundation now consists of:

1. independent repository infrastructure on `backup-01`;
2. a successful PostgreSQL full backup;
3. continuing PostgreSQL WAL archiving;
4. an independent Garage object backup;
5. a verified object manifest with retained SHA-256 identity.

This is backup-foundation evidence only. It does not yet prove restore correctness, PITR,
measured RPO/RTO, or full-system DR.

Immediate next phase:

**Phase 2 — independent PostgreSQL PITR experiment in a separate disposable recovery VM.**
