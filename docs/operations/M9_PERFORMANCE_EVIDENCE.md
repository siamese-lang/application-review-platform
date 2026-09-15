# M9 Performance — Live Evidence

Status: ACTIVE / PHASE 1 QUERY-PLAN BASELINE COMPLETE  
Last updated: 2026-09-15 UTC

This document retains sanitized M9 performance diagnosis and before/after evidence.
It does not contain credentials, session/CSRF material, private keys, or real personal data.

## Entry baseline

Planning/source main:

`17c6b845c1c51ecbee82b6151e1cc714315cec26`

Live runtime identity verified before diagnosis:

- Tokyo `loadgen-01`: `10.50.0.10`, `asia-northeast1-a`;
- backend release:
  `cea4ca09d05efd89bcb9227c866d841968c08547`;
- frontend release:
  `549511b0a8af9582125e89aaa2bde7fc4bffcd6d`;
- dataset M generated-namespace counts:
  - programs: 12;
  - users: 1,048;
  - applications: 100,000;
  - histories: 399,990;
  - audits: 499,990;
- deterministic interactive-overlay SHA-256:
  `f93dfb6a030fa552de3dd4c7b9c022368079680bf2b16b13c05883e8b678aae1`.

The live database also contains rows created/transitioned by the retained W3 run, so current
table totals/status distribution are not identical to the pristine generated namespace.
The M9 plan baseline therefore distinguishes generated-namespace identity from current live
table statistics.

## Phase 1 — reviewer queue SQL and plan baseline

### Representative request

The retained W3 reviewer path is:

`GET /api/v1/review/applications?status=SUBMITTED&size=20`

with ascending `updatedAt,id` ordering.

Application path:

- `ReviewerApplicationController.queue(...)`;
- `ApplicationService.reviewQueue(...)`;
- `ApplicationRepository.findReviewQueuePageByStatus(...)`.

Representative synthetic reviewer:

- username: `m6-reviewer`;
- reviewer ID: `2`;
- role: `REVIEWER`.

Current queue population for reviewer 2:

- SUBMITTED and unassigned: 10,542;
- SUBMITTED assigned to reviewer 2: 0;
- IN_REVIEW assigned to reviewer 2: 0.

The first returned page therefore consists of the earliest 20 unassigned SUBMITTED rows by
`updated_at,id`.

### Existing application indexes

At the Phase 1 baseline, `applications` has only:

- primary key on `id`;
- `idx_applications_applicant` on `applicant_id`.

There is no retained index specifically supporting reviewer queue status/reviewer filtering
or `updated_at,id` ordering.

### Measured M8 statements

The retained W3 `pg_stat_statements` entries remain:

- reviewer queue result query ID `5482672959566718733`:
  2,926 calls, mean execution time 417.049 ms;
- reviewer queue count query ID `1459435087802319229`:
  2,926 calls, mean execution time 305.405 ms.

The application-generated SQL contains both the reviewer-visibility OR predicate and an
additional explicit status predicate from the filtered pageable repository method.

### Quiet-window result plan

A read-only `EXPLAIN (ANALYZE, BUFFERS, VERBOSE)` was run with representative parameters:

- reviewer ID: 2;
- explicit status: SUBMITTED;
- page size: 20.

Observed result-plan characteristics:

- `Parallel Seq Scan` on `applications`;
- two workers plus leader;
- actual rows from the scan: about 3,514 per process, matching about 10,542 total target rows;
- estimated scan rows: 48 per process;
- rows removed by filter: 30,444 per process as reported by the plan;
- application-scan buffers: `shared hit=10816`;
- joins to users/programs occur after the application scan;
- final order uses `top-N heapsort` on `updated_at,id`;
- sort memory: 45 kB per process;
- full result-plan buffers: `shared hit=11242`;
- planning time: 1.690 ms;
- execution time: 75.271 ms;
- returned rows: 20.

The quiet-window execution time is not substituted for the W3 workload mean. It is retained
only as plan-level evidence. Under W3 saturation the same application statement family
averaged 417.049 ms.

### Quiet-window count plan

Observed count-plan characteristics:

- `Parallel Seq Scan` on `applications`;
- partial aggregate per process followed by `Gather` / `Finalize Aggregate`;
- estimated scan rows: 48 per process;
- actual rows: about 3,514 per process;
- buffers: `shared hit=10816`;
- planning time: 0.174 ms;
- execution time: 47.994 ms.

Under W3 saturation the corresponding count statement averaged 305.405 ms.

### Statistics/cardinality evidence

Current `applications` table statistics:

- estimated live tuples: 101,873;
- dead tuples: 2,621;
- last autoanalyze: 2026-09-15 02:18:27 UTC;
- autoanalyze count: 10;
- no manually created extended statistics exist for `applications`.

Relevant single-column statistics show:

- `status` has 6 distinct values;
- `reviewer_id` has a material null fraction and 49 observed non-null values;
- `updated_at` has high positive physical correlation.

Current exact status/reviewer distribution demonstrates a strong dependency that
single-column statistics do not describe:

- SUBMITTED: 10,542 total, all 10,542 have `reviewer_id IS NULL`;
- IN_REVIEW: 8,334 total, none have a null reviewer;
- APPROVED/NEEDS_REVISION/REJECTED likewise have non-null reviewers in the current data;
- DRAFT rows have null reviewers.

The stored `status` frequency was collected before the W3 mutation window completed, so
it is somewhat stale relative to the current status distribution. This is recorded as a
secondary estimation factor, not the sole explanation.

The current generated SQL also repeats the status condition logically:

`status = SUBMITTED AND ((status = SUBMITTED AND reviewer predicate) OR (status = IN_REVIEW ...))`

For this representative status-filtered request, the logical target reduces to the
SUBMITTED reviewer predicate, but the planner's estimate is far below the observed 10,542
rows. The evidence is consistent with both:

1. missing multicolumn dependency information for `status` and `reviewer_id`; and
2. duplicated status selectivity in the generated predicate.

### Phase 1 causal hypothesis

The measured reviewer queue cost has two distinct components:

1. **Access-path work**
   - no queue-specific index supports the status/reviewer filter and required
     `updated_at,id` order;
   - PostgreSQL therefore repeatedly scans the application table;
   - the result query joins the qualifying queue rows and sorts them before returning only
     20 rows;
   - the pageable count query repeats the application-table scan.

2. **Cardinality-estimation error**
   - the current status/reviewer distribution is strongly correlated;
   - only single-column statistics exist;
   - the generated status-filtered predicate repeats status conditions;
   - the planner estimates only 48 qualifying rows per process while about 3,514 are
     observed per process.

The evidence does **not** yet prove which intervention gives the best representative
improvement. Phase 1 therefore does not add an index, rewrite JPQL, add extended statistics,
change the count design, increase Hikari, resize the DB, or add cache.

## Phase 1 conclusion

Phase 1 is complete.

The next decision must compare bounded interventions against this retained baseline.
The first comparison should isolate query/predicate simplification without schema mutation,
then determine whether an access-path/index change is still required. A schema change is
not authorized until that comparison is recorded.


## Phase 2 — intervention comparison and decision

### Rejected option: query/predicate simplification alone

A read-only logically equivalent query removed the duplicated status structure while keeping
the same reviewer semantics:

`status = SUBMITTED AND (reviewer_id IS NULL OR reviewer_id = 2)`

Observed result-plan comparison:

- access path remained a sequential scan of `applications`;
- result buffers remained effectively unchanged:
  `shared hit=10816` for the application scan;
- actual qualifying rows remained 10,542;
- estimated qualifying rows improved from 48 per parallel process in the original plan to
  1,391 total in the simplified plan, but still materially underestimated reality;
- the simplified result plan lost parallel scan/gather behavior and used a single
  sequential scan plus joins;
- result execution time changed from 75.271 ms in the retained Phase 1 quiet-window plan to
  339.376 ms in this diagnostic run;
- count execution time changed from 47.994 ms to 42.625 ms.

The exact elapsed-time difference is not treated as a controlled before/after performance
claim because the plans were captured at different quiet-window moments. The structural
finding is decisive: simplifying the predicate did not reduce the table scan, buffer work,
or qualifying-row volume.

Decision: do not implement a JPQL rewrite as the first M9 intervention.

### Selected first intervention: reviewer queue access-path index

The first implementation changes only the database access path:

`applications(status, updated_at, id) INCLUDE (reviewer_id)`

Rationale:

- the measured endpoint always supplies an explicit status in the retained W3 reviewer
  scenario;
- equality on `status` matches the leading index key;
- `updated_at,id` matches the deterministic queue ordering;
- `reviewer_id` is retained in the index leaf so reviewer visibility can be evaluated
  without adding it ahead of the ordering keys;
- the change can help both the paged result and pageable count path;
- application query semantics remain unchanged, keeping causal attribution to one schema
  intervention.

Rejected/deferred alternatives:

- JPQL simplification alone: rejected by the diagnostic plan above;
- `(status, reviewer_id, updated_at, id)`: deferred because placing reviewer_id before the
  ordering keys can make the OR reviewer predicate and ordering interaction less direct for
  the measured page path;
- partial SUBMITTED-only index: deferred because it would overfit one status value more
  aggressively than necessary;
- extended statistics: deferred as a separate estimation intervention because it does not
  itself remove the measured full-scan access cost;
- Hikari/VM/PostgreSQL tuning/cache: rejected for this slice because none addresses the
  measured access path directly.

Implementation boundary:

- Flyway V7 creates the single index;
- no repository/JPQL change;
- a focused integration test verifies the migrated index definition;
- existing reviewer API integration tests remain the correctness guard for visibility and
  status semantics.

The index uses standard transactional `CREATE INDEX`. On this project-sized dataset this
keeps the Flyway path simple, but deployment must record migration/build time and acknowledge
that standard index creation can block concurrent writes while the index is built.


## Phase 3 — first intervention live verification

Release deployed:

`d90eb558bdb6317d49b0a7ce82148ddeb4b5babf`

Flyway live result:

- version: 7;
- description: `m9 reviewer queue access path`;
- script: `V7__m9_reviewer_queue_access_path.sql`;
- execution time: 277 ms;
- success: true.

Live index definition:

`CREATE INDEX idx_applications_review_queue_status_order ON public.applications USING btree (status, updated_at, id) INCLUDE (reviewer_id)`

### Post-index exact reviewer result plan

The original Hibernate result SQL was rerun with the same representative parameters.

Observed changes:

- access path changed from `Parallel Seq Scan` to
  `Index Scan using idx_applications_review_queue_status_order`;
- the index supplies `updated_at,id` ordering directly, so the previous top-N sort
  disappeared;
- application index scan returned the first 20 qualifying rows directly;
- application scan buffers dropped from `shared hit=10816` before the change to
  `shared hit=19 read=3` on the index scan;
- full plan buffers were `shared hit=80 read=3`;
- execution time changed from 75.271 ms in the retained pre-change quiet-window plan to
  0.750 ms in this post-change plan.

The quiet-window execution-time ratio is retained only as SQL-plan evidence, not as the
representative workload claim.

### Post-index exact reviewer count plan

Observed changes:

- count changed from `Parallel Seq Scan` to a bitmap path using
  `idx_applications_review_queue_status_order`;
- the count still evaluates all 10,542 matching SUBMITTED rows;
- heap blocks remained material: 5,920 exact blocks;
- buffers changed from `shared hit=10816` before the change to
  `shared hit=5923 read=76`;
- execution time changed from 47.994 ms to 19.570 ms.

This confirms the first intervention strongly improves the paged result path while leaving a
smaller but real residual count cost.

Phase 3 conclusion:

- migration/test/CI: PASS;
- exact release deployment: PASS;
- Flyway V7 live application: PASS;
- post-index exact SQL plan: PASS;
- no JPQL, pool, VM, cache, or PostgreSQL configuration change was bundled.

## Phase 4 — same-condition W2 remeasurement

Post-change W2 run:

`m8-w2-20260915T165007Z-d90eb558`

Comparable identity:

- source/release/backend/frontend:
  `d90eb558bdb6317d49b0a7ce82148ddeb4b5babf`;
- dataset M seed: `20260914`;
- dataset manifest SHA-256:
  `9e174ead7c9ae7b77d5adc18c93e336b4cac5e30b5962bf47c31de4f42bea696`;
- overlay SHA-256:
  `f93dfb6a030fa552de3dd4c7b9c022368079680bf2b16b13c05883e8b678aae1`;
- 30 VU / 15 minutes;
- frozen business mix preserved.

W2 workload result:

- business requests: 26,761 vs 26,864 before;
- non-file success: 100% vs 100%;
- non-file p95: 92.346 ms vs 222.197 ms before;
- regression target: PASS.

Target SQL means:

- applicant list:
  29.673 ms vs 30.784 ms before;
- reviewer queue result:
  3.491 ms vs 100.136 ms before;
- reviewer queue count:
  5.781 ms vs 67.933 ms before.

Reviewer workload-family latency:

- average: 53.141 ms;
- p95: 63.375 ms;
- p99: 191.842 ms;
- max: 2,174.452 ms.

The retained pre-change reviewer family p95 was 329.024 ms.

Interpretation:

- applicant-list SQL remained effectively unchanged;
- the targeted reviewer result/count statements improved by roughly 96.5% and 91.5% in mean
  execution time respectively;
- reviewer-family p95 improved by roughly 80.7%;
- overall W2 non-file p95 improved by roughly 58.4%;
- success remained 100%;
- the change is therefore revalidated under the representative normal-load profile without
  a correctness regression.

This is sufficient to proceed to the same-condition W3 bounded peak. Peak-load evidence is
still required before closing Phase 4 or promoting the performance evidence maturity.
