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
