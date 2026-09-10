# BACKUP & RECOVERY — M0 Frozen Baseline

Status: FROZEN

## Principles

- Replication is not backup.
- Persistent Disk is not backup.
- A restarted process is not proof of business recovery.
- Recovery claims use measured results only.

## Database recovery

`pgBackRest` manages PostgreSQL base/differential backup, WAL archiving, restore, and PITR. Database PITR is tested independently from full-system DR.

Internal design target, not a measured claim: DB PITR RPO ≤ 5 minutes and RTO ≤ 30 minutes.

## Object backup

Garage replication protects availability from node loss but does not protect against logical deletion. `backup-01` therefore holds an independent object backup and manifest containing object key, size, SHA-256, and backup timestamp.

## Whole-system checkpoint

PostgreSQL and Garage do not share a distributed transaction or common point-in-time snapshot. A verified maintenance checkpoint is therefore used for full DR:

1. Block new mutations temporarily.
2. Let in-flight mutations finish.
3. Verify attachment `PENDING` count is zero.
4. Create the PostgreSQL checkpoint backup.
5. Copy Garage objects.
6. Generate the manifest.
7. Verify the backup set.
8. Resume writes.

Internal design target, not a measured claim: full checkpoint DR RPO is the last verified checkpoint and RTO ≤ 60 minutes.

## Full DR

Full DR rebuilds new VMs using IaC/configuration, restores DB and objects, deploys the application image, then runs automated business invariants. It is not merely restarting the original VM.

Verification includes current application status matching latest history, no orphan applications, all `AVAILABLE` attachments existing in object storage, size/SHA-256 equality, valid references, and terminal applications having terminal history.

Whole-region loss combined with loss of the single `backup-01` repository is explicitly outside the project claim boundary.
