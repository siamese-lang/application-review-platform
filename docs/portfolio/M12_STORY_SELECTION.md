# M12 Phase 1 — Final Story Selection

Status: FINAL
Milestone: M12 Portfolio
Selection base: `eb4dca2e0b613868fa024782fddd8ecec5b679ef`

## Decision

The final primary-story budget is **three**.

Selected primary stories:

1. **M9 — PostgreSQL peak-load bottleneck diagnosis and bounded index intervention**
2. **M10 — Garage replication survived, fixed client endpoint did not**
3. **M11 — Recover business state, not just processes**

M6 immutable release/rollback remains a **strong supporting story**, not a primary story.

This selection is based on evidence coverage and overlap, not on an arbitrary score or the
number of technologies used.

## Why M9 qualifies for E5

The M9 evidence card was labeled E4 because its maturity label was not revisited after the
full M9 revalidation was appended.

The retained evidence now satisfies the repository E5 definition:

`problem → analysis → decision → action → verification → trade-off`

Specifically:

- observed problem:
  - W3 non-file p95 2,067.479 ms;
  - db-01 CPU average about 90.94%;
  - Hikari pending average about 39.52;
  - reviewer result/count means 417.049/305.405 ms;
- causal analysis:
  - exact reviewer result/count SQL retained;
  - `EXPLAIN (ANALYZE, BUFFERS)` showed parallel sequential scan, large buffer work, and
    explicit sort;
- rejected alternative:
  - predicate-only simplification was measured and rejected because the scan/buffer problem
    remained;
  - pool-size/cache/VM changes were also rejected because they did not address the measured
    access-path cause;
- bounded action:
  - one Flyway-managed
    `applications(status, updated_at, id) INCLUDE (reviewer_id)` index;
- same-condition verification:
  - W3 non-file p95 2,067.479 → 80.909 ms;
  - reviewer result/count means 417.049/305.405 → 0.645/9.497 ms;
  - db CPU average 90.94% → 37.113%;
  - Hikari pending average 39.52 → 1.256;
  - completed business requests 29,814 → 44,097;
- retained trade-off:
  - count query still processes the full matching set;
  - after-run transport outliers remain explicitly unresolved rather than hidden;
  - no second optimization was added once the measured bottleneck ceased to justify it.

No new experiment is required to promote this evidence to E5.

## Candidate comparison

### M6 — Exact immutable release and rollback

**Problem clarity**

Clear for an infrastructure/operations reviewer: the old path could deploy a working tree, but
could not independently prove that frontend/backend belonged to one reviewed immutable release
or that a previous release could be restored exactly.

**Causal evidence**

The evidence is primarily a control-gap proof rather than a failure diagnosis. The missing
release identity, immutable digest, current/previous state, and executed rollback are all
concrete, but there is no observed service incident to isolate.

**Decision quality**

Strong. Containerizing the runtime and destructive database rollback were explicitly rejected.
The selected exact-SHA bundle preserved the existing VM/JAR/static-frontend architecture.

**Verification strength**

Strong:

- exact SHA/digest identity;
- real B → A rollback;
- observed rollback command-to-readiness 38.346 s;
- full business/attachment smoke after rollback;
- return to B and final smoke.

**Distinctiveness / overlap**

Distinct change-management competency, but the final three selected stories already cover:

- evidence-driven performance change;
- fault isolation and minimum availability fix;
- disaster recovery/business-state restoration.

M6 is highly useful as supporting evidence for delivery discipline and is also reused in M11
through exact checkpoint-compatible release activation.

**Decision**

**Supporting story — high value.**

Keep it available for CI/CD, release-management, change-control, and rollback interview
questions, but do not spend one of the three primary story slots on it.

### M9 — PostgreSQL bottleneck diagnosis

**Problem clarity**

Very high. Representative peak load produced a measurable latency/throughput and DB saturation
problem.

**Causal evidence**

Strongest of the four candidates:

- workload telemetry;
- pg_stat_statements;
- exact SQL;
- EXPLAIN ANALYZE BUFFERS;
- rejected predicate-only alternative;
- same-condition remeasurement.

**Decision quality**

Strong. One measured index was chosen instead of pool/VM/cache/architecture expansion.

**Verification strength**

Very high, with comparable W2/W3 before/after conditions and multiple independent signals.

**Distinctiveness**

Adds direct SQL/database-performance analysis, which is not duplicated by M10/M11.

**Decision**

**Primary story. E5.**

### M10 — Garage fixed-endpoint failure

**Problem clarity**

Very high. A three-node replicated object store still lost attachment availability when the
application used one failed fixed endpoint.

**Causal evidence**

Very strong because R3a and R3b isolated endpoint role from object replication:

- non-endpoint node loss: 0% attachment error;
- configured-endpoint loss: 28.6920% attachment error;
- PostgreSQL/app/non-attachment path stayed healthy.

**Decision quality**

Strong. Broader HA redesign or managed products were rejected; one app-local failover proxy was
chosen as the minimum correction.

**Verification strength**

Very high. The same storage-01 fault was repeated and attachment errors went to 0% with no new
FAILED/PENDING/DELETE_PENDING lifecycle residue.

**Distinctiveness**

Demonstrates fault isolation, blast-radius reasoning, minimal architecture change, and same-fault
revalidation. It is an availability story rather than a backup/recovery story.

**Decision**

**Primary story. E5.**

### M11 — Disaster recovery correctness

**Problem clarity**

High. Service/process restart cannot prove that PostgreSQL business state and attachment object
bytes are jointly recoverable.

**Causal evidence**

The story is a recovery-proof problem rather than an incident root-cause problem, but the
evidence chain is unusually strong:

- independent PITR marker boundary;
- explicit cross-store checkpoint;
- fresh recovery infrastructure;
- exact DB/object/release identities;
- business/history/audit/attachment integrity checks.

**Decision quality**

Strong. PostgreSQL HA, managed DB, replacement storage, and replication-as-backup were not used
to inflate scope. The existing architecture was recovered with explicit consistency boundaries.

**Verification strength**

Very high:

- DB PITR RTO 27.229 s;
- marker recovery gap ≤1.087882 s;
- PRE included / POST excluded;
- 21 checkpoint objects key/size/SHA verified;
- HTTPS applicant/reviewer workflow passed;
- `M11_FULL_DR_INTEGRITY=PASS`;
- final temporary-resource cleanup and persistent no-drift.

**Distinctiveness / limit**

Distinct from M10 because it addresses recoverability after data/system loss rather than
single-node online availability.

Its main limitation is retained: no authoritative end-to-end full-DR RTO or effective
full-system RPO is claimed.

**Decision**

**Primary story. E5.**

## Final coverage

The three primary stories cover different engineering questions.

### 1. M9 — Performance / database

**Question:** What do you do when a system becomes slow under representative load?

Evidence sequence:

`workload → telemetry → SQL → plan → rejected alternative → one index → same-load remeasurement`

Core competency:

- measurement before optimization;
- direct PostgreSQL/query-plan reasoning;
- bounded change;
- performance trade-off.

### 2. M10 — Reliability / fault isolation

**Question:** What do you do when redundancy exists but the application still fails?

Evidence sequence:

`fault A vs fault B → isolate endpoint dependency → minimal failover boundary → same-fault retest`

Core competency:

- failure-domain reasoning;
- blast-radius isolation;
- smallest justified architecture change;
- revalidation under the original fault.

### 3. M11 — Recovery / business continuity

**Question:** How do you prove that the service can recover its actual business state?

Evidence sequence:

`backup identity → PITR boundary → cross-store checkpoint → fresh DR rebuild → business/integrity checks → cleanup`

Core competency:

- backup vs replication distinction;
- point-in-time recovery;
- cross-store consistency boundary;
- recovery correctness and claim discipline.

Together these cover **performance, reliability, and recovery** without making the portfolio
three versions of the same infrastructure story.

## Supporting role of M6

M6 remains part of the final project narrative because it proves the delivery/control substrate:

- exact reviewed release identity;
- immutable artifact digest/checksum;
- paired frontend/backend activation;
- schema-compatible rollback;
- real rollback drill and business revalidation.

It should be used when the audience or job emphasizes CI/CD, release engineering, deployment,
change control, or rollback.

It is not discarded; it is simply not one of the three headline cases.

## Supporting evidence outside the four candidates

The final portfolio may reference, but should not promote to additional headline stories:

- optimistic-lock reviewer claim correctness;
- attachment DB/object consistency and SHA-256 checks;
- M7 metrics/logs/traces and alerting;
- M5 browser/API/session/CSRF product boundary;
- OpenTofu/Ansible reproducibility and no-drift verification.

These make the primary stories credible but do not need separate résumé bullets.

## Claim boundaries to preserve

### M9

- 100 offered business requests/s and 100-VU ceiling are bounded project conditions, not
  production capacity.
- internal latency target is not an SLA.
- exact cause of the retained post-change client/transport outliers is not claimed.

### M10

- one bounded single-Garage-node fault was tested;
- app-01 remains a single application failure domain;
- PostgreSQL HA and multi-node/storage-region failure were not tested;
- the earlier 64 FAILED rows were reset before retest, not automatically reconciled.

### M11

- DB PITR has measured RPO/RTO evidence;
- checkpoint maintenance timings are not full-DR RTO;
- no authoritative end-to-end full-DR RTO or effective full-system RPO is claimed;
- PostgreSQL remains a single primary;
- continuous multi-region availability was not implemented.

## Phase 1 conclusion

M12 Phase 1 is complete.

Final primary stories:

1. M9 PostgreSQL performance diagnosis — E5;
2. M10 Garage endpoint reliability — E5;
3. M11 disaster recovery correctness — E5.

M6 immutable release/rollback remains the strongest supporting story.

Immediate next work:

**Phase 2 — create the final-system portfolio master narrative without retelling the milestone
chronology.**
