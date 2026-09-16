# M10 Reliability — Completed Plan

Status: COMPLETE
Completed: 2026-09-16 UTC

## Goal

Verify bounded runtime failure behavior with retained evidence for blast radius, detection,
recovery, business-state impact, and one evidence-justified corrective change if required.

## Executed scope

- R1 application process failure — complete.
- R2 PostgreSQL primary outage — complete.
- R3 Garage single-node failure:
  - R3a non-endpoint node loss — complete;
  - R3b fixed-endpoint node loss — complete;
  - ADR-005 same-fault corrective-change retest — complete.
- R4 bad deployment/rollback — satisfied by retained M6 evidence.
- R5 logical corruption/PITR — deferred to M11 as planned.

Detailed original execution plan is retained unchanged at:

`docs/plans/completed/M10-reliability-execution-plan.md`

## Completion result

The strongest M10 finding was that Garage replication did not by itself preserve application
attachment availability while the client used one fixed endpoint.

R3b baseline:

- attachment error rate: 28.6920%;
- existing-object download error: 27.8481%;
- upload error: 27.0042%;
- 64 FAILED rows retained.

ADR-005 introduced one app-local Nginx failover proxy over storage-01/02/03.

Same-fault retest:

`m10-r3b-retest-20260916T071400Z-70e1b7f3`

- attachment error rate: 0%;
- non-attachment error rate: 0%;
- no new attachment lifecycle residue;
- intended storage-01-only telemetry transition captured;
- application process stayed stable;
- post-recovery business smoke passed.

## Closeout

- temporary M10 load generator topology removed;
- destroy apply: 0 added / 0 changed / 4 destroyed;
- persistent runtime final OpenTofu plan: no changes;
- M10 E5 evidence card committed;
- no second HA change introduced;
- PostgreSQL single-primary limitation retained explicitly;
- next reliability/recovery scope is M11 DR/PITR.
