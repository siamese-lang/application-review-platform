# M9 Performance — Execution Plan

Status: ACTIVE

## Goal

Use the representative M8 workload evidence to diagnose and improve a real measured
performance bottleneck without changing the frozen architecture or choosing a solution in
advance.

M9 answers:

> Which measured database/query change, if any, materially improves the representative
> workload under comparable conditions, and what evidence proves the improvement?

M9 is successful when it retains a causal chain of:

`M8 workload → measured SQL → EXPLAIN (ANALYZE, BUFFERS) → hypothesis → bounded change → same-condition remeasurement`

A negative result is valid. M9 does not require every measured candidate to be optimized.

## Planning base and prerequisites

Planning base:

`f8d996852d901ba44c1add8945d6831e54601eda`

M8 Workload closeout is complete.

Post-merge `main` CI:

- run `407`;
- event: push;
- conclusion: SUCCESS.

Primary retained evidence:

- `docs/operations/M8_WORKLOAD_EVIDENCE.md`;
- `docs/portfolio/M8_POSTGRESQL_QUERY_BOTTLENECK_EVIDENCE.md`;
- `docs/plans/completed/M8-workload.md`.

The retained runtime remains intentionally available for comparable remeasurement:

- Seoul business runtime:
  `edge-01`, `app-01`, `db-01`, `storage-01`, `storage-02`,
  `storage-03`, `ops-01`, `obs-01`;
- Tokyo private `loadgen-01`, `e2-standard-2`, `10.50.0.10`;
- dataset M seed: `20260914`;
- dataset M manifest SHA-256:
  `9e174ead7c9ae7b77d5adc18c93e336b4cac5e30b5962bf47c31de4f42bea696`;
- retained `storage-03` overrides:
  machine `e2-small`, boot disk `pd-standard`.

M8 final OpenTofu plan reported no changes.

Do not recreate W1/W2/W3 merely to reconfirm M8. The first M9 task is query-plan diagnosis.

## Measured M8 baseline

### W2 normal baseline

Run:

`m8-w2-20260914T203329Z-ac3d7657`

Profile:

- dataset M;
- 30 VU;
- 15 minutes;
- frozen business mix;
- 26,864 business requests.

Result:

- non-file success: 100%;
- non-file p95: 222.197 ms;
- internal regression target: PASS;
- Hikari pending: 0;
- db-01 CPU: average about 36.7%, max about 52.8%.

Measured SQL means:

- applicant list: 30.784 ms;
- reviewer queue result: 100.136 ms;
- reviewer queue count: 67.933 ms.

### W3 bounded peak baseline

Run:

`m8-w3-20260915T021822Z-d6c30508`

Profile:

- dataset M;
- 10 minutes;
- offered 100 business requests/s;
- frozen offered mix 40/15/10/20/10/5;
- hard 100-VU ceiling.

Result:

- completed iterations: 17,336;
- dropped iterations: 15,668, about 47.5% of scheduled iterations;
- completed business requests: 29,814, about 49.7 requests/s;
- non-file success among executed requests: 100%;
- non-file p95: 2,067.479 ms;
- internal regression target: FAIL;
- support-path error rate: about 6.07%;
- Hikari active: average about 8.61, max 10;
- Hikari pending: average about 39.52, max 54;
- db-01 CPU: average about 90.94%, max about 99.98%;
- PostgreSQL deadlocks: 0;
- edge saturation signals: absent;
- private application probe: healthy.

Measured SQL means:

- applicant list: 215.726 ms;
- reviewer queue result: 417.049 ms;
- reviewer queue count: 305.405 ms.

Compared with W2, those means increased about 7.0x/4.2x/4.5x.

## Ranked M9 candidates

### Candidate 1 — reviewer queue result/count pair

This is the first M9 analysis target.

M8 query IDs:

- result: `5482672959566718733`;
- count: `1459435087802319229`.

The workload calls:

`GET /api/v1/review/applications?status=SUBMITTED&size=20`

with ascending `updatedAt,id` ordering.

The current application path is:

- `ReviewerApplicationController.queue(...)`;
- `ApplicationService.reviewQueue(...)`;
- `ApplicationRepository.findReviewQueuePageByStatus(...)`.

The repository query combines reviewer visibility logic with an explicit status filter, while
Spring Data pagination also issues a count query. The measured result and count statements
must be diagnosed separately because either may dominate after a change.

This plan does not assume the cause is a missing index, an OR predicate, the entity graph,
the sort, the count query, or any other specific mechanism.

### Candidate 2 — applicant application list

M8 query ID:

`4815990123001274496`.

The workload calls:

`GET /api/v1/applications?size=20`

with descending `updatedAt,id` ordering.

Current path:

- `ApplicantApplicationController.list(...)`;
- `ApplicationService.mine(...)`;
- `ApplicationRepository.findByApplicant(...)`.

The existing schema has an `applications(applicant_id)` index, but M8 showed this query
becoming materially expensive under saturation. M9 must inspect its actual plan before
deciding whether it requires any change.

Candidate 2 is not changed in the same first optimization slice merely because it is also
slow. Keep attribution clear.

### Correlated signals, not independent fixes

- Hikari pending;
- DB CPU saturation;
- PostgreSQL backend count.

These are evidence that the database path is under pressure. They are not standalone reasons
to increase pool size or resize the DB.

## Constraints

### 1. No predetermined solution

Do not begin M9 by:

- adding an index because one looks plausible;
- rewriting JPQL because the predicate looks awkward;
- increasing Hikari pool size;
- resizing app/db nodes;
- adding Redis/cache;
- changing PostgreSQL configuration;
- changing the frozen workload to make the result look better.

First capture the actual plan and measured work.

### 2. Preserve comparable conditions

Before/after workload comparisons must retain:

- dataset M;
- seed `20260914`;
- same deterministic interactive overlay;
- Tokyo `loadgen-01`;
- same loadgen machine type;
- same real HTTPS/session/CSRF boundary;
- same W2 30-VU/15-minute profile;
- same final W3 arrival-rate profile, duration, offered mix, and 100-VU ceiling;
- unchanged business-node sizes unless the experiment explicitly reaches a later
  evidence-supported capacity phase.

Record exact source/release SHA for every retained after-run.

### 3. One causal change at a time

Prefer one intervention that can be attributed to the measured plan.

If diagnosis suggests more than one material change:

1. choose the smallest/highest-confidence change;
2. remeasure it;
3. retain the result;
4. only then decide whether a second change is justified.

Do not combine an index, JPQL rewrite, pool resize, and VM resize into one comparison.

A tightly coupled query/index change may be split into sequential PRs if attribution would
otherwise be ambiguous.

### 4. Schema changes use Flyway only

If the selected change adds/drops/changes an index or other schema object:

- use the next Flyway migration;
- do not apply a manual live-only DDL shortcut;
- account for migration locking/build cost;
- if a schema experiment must be reversed after deployment, use a compensating migration
  rather than pretending Flyway supports automatic down-migration.

Do not create a migration until query-plan evidence supports it.

### 5. Preserve correctness

Performance work must not change reviewer visibility, ownership, state-transition, ordering,
pagination, or audit/history behavior.

Relevant reviewer queue semantics include:

- unassigned SUBMITTED applications are visible;
- SUBMITTED applications assigned to the current reviewer remain visible as intended;
- IN_REVIEW applications are visible only to their assigned reviewer;
- applications assigned to another reviewer are excluded;
- explicit status filtering remains correct;
- pagination order remains deterministic by `updatedAt,id`.

Applicant list ownership/status behavior must remain unchanged if Candidate 2 is later
modified.

### 6. M9 evidence maturity

The PostgreSQL bottleneck evidence is E3 at M9 entry.

Promote to E4 only when a specific change is revalidated under comparable conditions.

Do not promote to E5 merely because latency improves. Portfolio-ready maturity still
requires the complete problem → analysis → decision → verification → trade-off story.

## Expected files/components

Likely repository areas:

- `docs/plans/active/M9-performance.md`;
- `docs/operations/M9_PERFORMANCE_EVIDENCE.md`;
- `docs/portfolio/M8_POSTGRESQL_QUERY_BOTTLENECK_EVIDENCE.md`;
- `docs/portfolio/PORTFOLIO_EVIDENCE_MAP.md`;
- `docs/AI_PROJECT_STATE.md`;
- `app/src/main/java/com/siameselang/arp/repository/ApplicationRepository.java`
  only if query evidence supports a repository change;
- `app/src/main/resources/db/migration/`
  only if schema evidence supports a migration;
- focused application/repository integration tests;
- a small repository-owned M9 SQL/plan capture script under `scripts/performance/` or
  another existing script area if repeatability requires it;
- existing M8 workload runners for comparable remeasurement.

Do not create a general-purpose benchmarking framework.

## Verification model

Every meaningful M9 intervention must have four evidence layers where applicable:

1. **SQL plan**
   - exact target SQL and representative parameters;
   - `EXPLAIN (ANALYZE, BUFFERS)`;
   - actual rows vs estimated rows;
   - scan/join/sort/filter operations;
   - rows removed by filter;
   - buffer hits/reads;
   - planning/execution time.

2. **application correctness**
   - focused tests for the affected list/queue semantics;
   - existing integration/concurrency tests remain green.

3. **representative workload**
   - W2 normal baseline equivalent;
   - W3 bounded offered-load equivalent when the change is a peak candidate;
   - same dataset/security/loadgen conditions.

4. **server/database correlation**
   - candidate `pg_stat_statements` mean/total/calls;
   - Hikari active/pending;
   - DB CPU;
   - PostgreSQL connections/deadlocks;
   - application availability;
   - edge/storage signals as controls.

Do not claim improvement from SQL plan time alone or from a single client p95 alone.

## Implementation phases

### Phase 1 — exact SQL and read-only plan baseline

Status: **COMPLETE**

Goal: reproduce the measured reviewer queue result/count statements against dataset M and
retain plan-level evidence before making any performance change.

Tasks:

1. lock the current reviewed `main` SHA;
2. verify dataset M/runtime identity without changing performance configuration;
3. identify representative synthetic reviewer/status/page parameters matching W3;
4. retain the exact reviewer queue result SQL and count SQL corresponding to the measured
   application path;
5. run read-only `EXPLAIN (ANALYZE, BUFFERS)` during a quiet diagnostic window;
6. retain both human-readable and/or structured sanitized plan evidence;
7. compare the plan evidence with the M8 `pg_stat_statements` measurements;
8. write the first causal hypothesis only after the plans are observed.

The retained Phase 1 result is documented in `docs/operations/M9_PERFORMANCE_EVIDENCE.md`.

Done condition:

- exact SQL and parameter meaning are documented;
- reviewer result and count plans are retained;
- the dominant scan/join/sort/filter/buffer work is identified from observed plans;
- no performance change has been made.

### Phase 2 — choose one bounded intervention

Status: **COMPLETE**

Use Phase 1 evidence to compare the smallest plausible options.

Immediate Phase 2 comparison order:

1. run a read-only logically equivalent status-specific reviewer query to isolate the effect
   of removing redundant status predicates without changing schema;
2. compare its plan/cardinality/execution with the retained Phase 1 plan;
3. decide whether query simplification alone is material enough to implement;
4. if table scan/order work remains dominant, evaluate the smallest queue-specific access
   path/index design using the observed filter/order semantics;
5. keep statistics/extended-statistics changes separate from access-path changes so their
   effects remain attributable.

Possible classes include, only if supported by the plan:

- index design;
- query/predicate simplification;
- pagination/count-query design;
- fetch/join shape.

Do not rank an option before Phase 1 plan evidence exists.

Record:

- observed problem;
- proposed mechanism;
- why it should affect the measured operation;
- alternatives considered;
- correctness risks;
- migration/deployment implications;
- exact remeasurement expectations.

Done condition:

- one intervention is selected from evidence;
- the plan states why other plausible changes are deferred/rejected;
- no unrelated performance change is bundled.

Phase 2 decision:

- predicate simplification alone was rejected after a read-only diagnostic retained the same
  sequential-scan/buffer work;
- first intervention is one Flyway index:
  `applications(status, updated_at, id) INCLUDE (reviewer_id)`;
- application JPQL remains unchanged;
- extended statistics, pool sizing, VM sizing, cache, and additional indexes remain deferred.

### Phase 3 — implement and verify the first intervention

Status: **COMPLETE**

Implement only the selected intervention.

Required verification:

- focused correctness/integration tests;
- migration validation when applicable;
- exact-head CI;
- no weakening/removal of existing tests;
- no architecture expansion.

If the intervention touches query semantics, explicitly test reviewer visibility, status
filtering, deterministic ordering, and pagination.

Done condition:

- exact-head CI passes;
- code/migration diff matches the Phase 2 decision;
- no performance claim is made yet.

### Phase 4 — deploy and same-condition remeasurement

Status: **ACTIVE**

Retained Phase 4 progress:

- exact release `d90eb558bdb6317d49b0a7ce82148ddeb4b5babf` deployed;
- Flyway V7 applied successfully in 277 ms;
- exact result/count SQL plans rechecked after deployment;
- W2 same-condition run `m8-w2-20260915T165007Z-d90eb558` PASS;
- W2 non-file p95: 92.346 ms vs 222.197 ms before;
- reviewer result/count means: 3.491/5.781 ms vs 100.136/67.933 ms before;
- next required step: same-condition W3 bounded peak remeasurement.

Deploy the exact reviewed release through the existing M6 delivery path.

Then:

1. restore deterministic dataset M and the same overlay;
2. confirm observability health;
3. reset `pg_stat_statements`;
4. retain the post-change query plan under comparable parameters;
5. run W2 under the same 30-VU/15-minute conditions;
6. run final open-model W3 under the same 100 business req/s / 100-VU-ceiling / 10-minute
   conditions when the change is intended to affect peak saturation;
7. correlate client, app, DB, and control signals.

Before/after comparison must include at least:

- candidate SQL plan shape and execution/buffer work;
- query mean/total/calls from `pg_stat_statements`;
- W2 non-file p95 and success;
- W3 non-file p95;
- W3 completed vs dropped iterations;
- completed business throughput;
- Hikari pending;
- DB CPU;
- application probe;
- error/support-path rates.

Do not require an arbitrary percentage improvement to call the experiment valid.

An improvement claim requires:

- correctness preserved;
- no material W2 regression;
- plan/query evidence moving in the expected direction;
- representative workload evidence consistent with the SQL-level result.

If the change does not improve the measured problem, retain the negative result rather than
rerunning until a favorable number appears.

### Phase 5 — residual bottleneck decision

Status: PLANNED

After the first intervention is remeasured:

- if reviewer queue work remains the dominant measured limit, decide whether a second
  evidence-supported reviewer-path intervention is justified;
- if applicant list becomes the dominant remaining database cost, analyze Candidate 2 with
  its own `EXPLAIN (ANALYZE, BUFFERS)` before changing it;
- if W3 no longer exposes a worthwhile database bottleneck, stop;
- do not optimize unrelated attachment/storage/application paths merely because M9 exists.

Any second intervention repeats the same
plan → change → correctness → W2/W3 remeasurement loop.

### Phase 6 — M9 closeout

Status: PLANNED

Required closeout:

- sanitized M9 performance evidence;
- retained before/after plans;
- exact source/release/run identities;
- options and rejected alternatives;
- successful or negative remeasurement result;
- Evidence Map update;
- Evidence Card update from E3 to E4 only when comparable revalidation supports it;
- explicit remaining bottleneck/trade-off;
- final runtime drift check;
- explicit `loadgen-01` lifecycle decision;
- active M9 plan moved to completed;
- exact-head CI and post-merge `main` CI successful.

If M10 immediately requires the same load generator for controlled fault workloads, retain
it only with that reason recorded. Otherwise destroy the temporary M8/M9 loadgen at M9
closeout through the reviewed OpenTofu lifecycle.

## Stop/continue rules

Stop an optimization branch when:

- plan evidence contradicts the hypothesis;
- correctness would require disproportionate complexity;
- the change moves cost elsewhere without improving representative behavior;
- the measured gain is negligible relative to added complexity;
- the current candidate is no longer material.

Continue to another candidate only when retained after-measurement identifies a concrete
remaining bottleneck.

Do not use M9 to chase the internal p95 target by stacking changes without causal evidence.

## Completion criteria

M9 is complete only when:

- the measured reviewer queue SQL has retained pre-change
  `EXPLAIN (ANALYZE, BUFFERS)` evidence;
- at least one evidence-supported performance intervention has been evaluated, unless plan
  evidence proves that no safe/useful intervention is justified;
- every implemented schema change uses Flyway;
- affected business semantics have focused correctness coverage;
- any claimed performance improvement has comparable post-change W2/W3 evidence;
- negative/no-improvement results are retained when they occur;
- no speculative Redis/cache/pool/VM/architecture change was introduced;
- portfolio evidence maturity reflects only what was actually revalidated;
- runtime drift and temporary loadgen lifecycle are explicitly resolved;
- final exact-head and post-merge `main` CI pass.
