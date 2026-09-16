# M10 Reliability Evidence

Status: FINAL / M10 COMPLETE

## Canonical closeout evidence

Detailed final closeout record:

`docs/operations/M10_PHASE6_CLOSEOUT_EVIDENCE.md`

Pre-closeout chronological evidence retained unchanged at:

`docs/operations/M10_RELIABILITY_EVIDENCE_PRE_CLOSEOUT.md`

Portfolio evidence card:

`docs/portfolio/M10_GARAGE_ENDPOINT_FAILOVER_EVIDENCE.md`

## Final retained result

M10 executed the bounded reliability scope without expanding into a general HA redesign.

- R1 application process failure: existing systemd recovery worked; no architecture change.
- R2 PostgreSQL outage: single-primary availability limitation confirmed and retained.
- R3a Garage non-endpoint loss: 0% observed attachment/non-attachment error.
- R3b fixed storage-01 endpoint loss: 28.6920% attachment error and 64 FAILED rows.
- ADR-005: one app-local Nginx Garage S3 failover proxy selected as the only corrective change.
- Same-fault R3b retest:
  `m10-r3b-retest-20260916T071400Z-70e1b7f3`
  - 240 attachment attempts;
  - 0% existing-read/upload/download/delete error;
  - 480 non-attachment attempts;
  - 0% non-attachment/support error;
  - no new FAILED/PENDING/DELETE_PENDING residue;
  - storage-01 telemetry 1→0→1 while storage-02/03, PostgreSQL, and application probe remained healthy;
  - application MainPID remained stable;
  - full post-recovery HTTPS business smoke passed.
- Temporary M10 loadgen/subnet/router/NAT removed: 0 add / 0 change / 4 destroy.
- Final persistent-runtime OpenTofu plan: no changes.
- R4 remains satisfied by M6 rollback evidence.
- R5 logical corruption/PITR remains M11 scope.

The earlier 64 FAILED rows remain retained baseline evidence. The guarded Dataset M reset before
the retest reset the synthetic live dataset; it did not prove automatic reconciliation of FAILED rows.

## Final limitation

The single PostgreSQL primary remains the main documented availability limitation from M10.
No PostgreSQL HA or second Garage HA layer was added.
