# M11 Phase 5 Residual Recovery Decision Evidence

Status: COMPLETE  
Milestone: M11 Disaster Recovery  
Decision date: 2026-09-16 UTC  
Decision base main SHA: `753078df49d3fd2e09737b4a0a4988cfef01076c`

## Decision

No additional corrective recovery implementation is justified by the retained M11 evidence.

Phase 5 therefore closes without:

- another PostgreSQL restore;
- another Garage restore;
- another full DR rebuild;
- another representative business smoke;
- PostgreSQL HA;
- multi-region HA;
- a second backup platform;
- another datastore or object-storage layer.

The remaining work is Phase 6 closeout: cleanup, retained-runtime restoration/no-drift
verification, evidence-map/card decision, and final milestone documentation.

## Evidence reviewed

### Phase 2 — independent PostgreSQL PITR

Retained evidence:

`docs/operations/M11_PHASE2_PITR_EVIDENCE.md`

Frozen internal DB PITR targets:

- RPO ≤ 5 minutes;
- RTO ≤ 30 minutes.

Measured result:

- recovered marker state: PRE included / POST excluded;
- marker-granularity recovery gap: **≤ 1.087882 seconds** before the requested target;
- business/data verification complete: **27.229 seconds** from restore start;
- orphan applications: 0;
- application/latest-history mismatch: 0;
- terminal-history missing: 0.

Decision:

- DB PITR RPO target: **met by measured marker evidence**;
- DB PITR RTO target: **met by measured restore evidence**;
- no residual PostgreSQL recovery correction is justified.

### Phase 4 — full DR rebuild and business recovery

Retained evidence:

`docs/operations/M11_PHASE4_FULL_DR_EVIDENCE.md`

Verified result:

- repository-defined separate DR topology created;
- exact checkpoint PostgreSQL backup restored;
- exact checkpoint Garage object set restored;
- checkpoint-compatible release activated;
- public HTTPS boundary passed with normal TLS verification;
- representative applicant/reviewer workflow passed;
- restored reviewer/state/history/audit invariants passed;
- 17 checkpoint AVAILABLE attachment rows matched DB ↔ manifest ↔ recovered Garage by
  key, size, and SHA-256;
- checkpoint PENDING/FAILED/DELETE_PENDING counts were 0/0/0;
- post-checkpoint smoke data remained distinguishable from checkpoint data;
- overall restored integrity result: `M11_FULL_DR_INTEGRITY=PASS`.

The live recovery defects encountered during Phase 4 were already corrected inside Phase 4:

1. Garage restore playbook path did not load shared `group_vars`; the playbook was moved into
   `config/ansible/` and a static contract was added.
2. GCP global CPU quota prevented the complete topology from being created in one pass; partial
   state was preserved and retained VMs were stopped without deleting disks/IaC so the reviewed
   recovery topology could complete.

The Garage defect was an implementation defect and is already corrected.

The CPU quota event is retained as an operational capacity constraint. It does not demonstrate
a defect in the frozen backup/restore architecture, and adding a new HA layer, provider, or
capacity platform would exceed the bounded corrective scope.

## Full-DR RPO/RTO limitation

Phase 4 retained reliable component timings, including:

- PostgreSQL restore command: 10.961 seconds;
- PostgreSQL ready: 15.006 seconds;
- PostgreSQL initial invariant verification complete: 16.051 seconds;
- Garage restore + complete target verification: 0.766 seconds.

These measurements are not an end-to-end full-DR RTO.

The exercise did not retain one authoritative recovery-start timestamp and one business-ready
completion timestamp across:

- quota interruption;
- partial IaC continuation;
- DR configuration;
- DB restore;
- Garage corrective change and restore;
- release activation;
- TLS bootstrap;
- business smoke;
- final integrity verification.

For the same reason, no effective full-system RPO relative to a single simulated disaster
timestamp is claimed.

Phase 5 classifies this as an **evidence limitation**, not a failed recovery invariant.

A corrective implementation would only be justified if recovery correctness, integrity, or a
measured target had failed. Re-running the entire full DR solely to manufacture an end-to-end
number would add cost and repetition without correcting a demonstrated system defect.

Therefore:

- do not sum component timings and label the result full-DR RTO;
- do not claim the ≤60 minute full-DR design target was achieved;
- retain the missing authoritative full-DR timing boundary explicitly in M11 closeout;
- a future drill may add a single authoritative end-to-end timer if full-DR RTO measurement
  becomes a project requirement.

## Residual limitations carried into closeout

1. Full-DR end-to-end RTO is not measured.
2. Effective full-system RPO relative to one simulated disaster time is not measured.
3. Whole-region loss combined with loss of the single `backup-01` repository remains outside
   the project claim boundary.
4. PostgreSQL remains a single primary; automatic database failover is intentionally outside M11.
5. Temporary DR creation depended on available GCP global CPU quota during this exercise.

These limitations are explicit scope/evidence boundaries. None requires a bounded corrective
implementation before M11 closeout.

## Phase 5 conclusion

Result:

`M11_PHASE5_CORRECTIVE_CHANGE=NONE`

Rationale:

- measured DB PITR RPO/RTO met the frozen internal targets;
- full DR recovery correctness and attachment/business integrity passed;
- the implementation defect exposed by Garage restore was already corrected and regression
  guarded during Phase 4;
- remaining full-DR timing gaps are evidence limitations rather than failed recovery behavior;
- further infrastructure/HA work would exceed the frozen milestone scope.

Immediate next work:

**Phase 6 — M11 closeout.**

Phase 6 must remove temporary recovery infrastructure through a reviewed destroy plan, restore
the retained Seoul runtime state affected by the quota workaround, verify final persistent
OpenTofu no-drift, retain sanitized closeout evidence, update the portfolio evidence map/card as
warranted, and complete the M11 plan.
