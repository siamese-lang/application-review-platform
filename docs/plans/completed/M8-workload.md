# M8 Workload — Execution Plan

Status: COMPLETE

## Goal

Create representative, repeatable synthetic data and business workloads that exercise the
real deployed API boundary and produce trustworthy baseline evidence for M9 Performance
analysis.

M8 answers:

> Under controlled, repeatable business-like conditions, how does the current system behave,
> and which paths are worth investigating further?

M8 does **not** optimize the system. It establishes the conditions and evidence required to
decide whether an optimization is justified.

## Planning base and prerequisite

Planning base:

`320fdbe5d8c8d90c50d5c6aeac61f8994fcd3c8e`

M7 Observability closeout is complete.

Post-merge `main` baseline CI run `34857098170`: **SUCCESS**.

M7 leaves the live environment intentionally retained:

- eight-node primary runtime in Seoul:
  `edge-01`, `app-01`, `db-01`, `storage-01`, `storage-02`,
  `storage-03`, `ops-01`, `obs-01`;
- Prometheus/Loki/Tempo/Grafana/Alertmanager/Alloy verified live;
- business smoke verified while central observability was unavailable;
- final runtime OpenTofu plan: no changes;
- M7 evidence maturity: E2 enabling infrastructure.

Source evidence:

- `docs/operations/M7_OBSERVABILITY_EVIDENCE.md`;
- `docs/workload/WORKLOAD.md`;
- `docs/PROJECT_EXECUTION.md`;
- `docs/architecture/ADR-004-gcp-resource-placement.md`.

Do not rerun completed M7 verification unless new evidence requires it.

## Frozen workload contract

M8 implements the existing frozen workload baseline rather than inventing a new benchmark.

Synthetic dataset targets:

- S: about 10,000 applications for development;
- M: about 100,000 applications and 400,000 history rows for baseline tests;
- L: about 500,000 applications and 2,000,000 history rows for later performance tests;
- one million applications remains optional only if L fails to expose meaningful behavior.

Initial API workload mix:

- application/program list/detail: 40%;
- create/save application: 15%;
- submit/resubmit: 10%;
- reviewer queue/detail: 20%;
- start/approve/reject/request-revision: 10%;
- attachment upload/download: 5%.

The initial normal baseline is approximately 30 VU for 15 minutes on dataset M.

The project-internal non-file API regression target remains:

- success >= 99%;
- p95 < 500 ms.

This is an internal acceptance target, **not** a customer SLA or production SLO.

## Core principles

### 1. Repeatability before scale

Every retained run must record enough metadata to reproduce the condition:

- source/release SHA;
- dataset size and fixed seed;
- dataset manifest/version;
- load-generator region and machine type;
- API scenario/mix version;
- VU profile;
- duration;
- think-time model;
- attachment fixture characteristics when applicable;
- infrastructure/runtime identity;
- start/end timestamps.

Do not compare two runs as before/after evidence if these conditions materially differ.

### 2. Real security boundary

Protected write scenarios must use the deployed authentication/session and CSRF behavior.

Do not:

- bypass Spring Security;
- disable CSRF;
- invoke hidden internal-only shortcuts merely to improve k6 throughput;
- use real personal/company data.

Synthetic users and business records only.

### 3. Separate load generation from measured hosts

Per ADR-004:

- k6 runs from a separate temporary `loadgen-01`;
- default region is `asia-northeast1` (Tokyo), subject to live quota/capacity checks;
- do not run k6 on `obs-01`, `app-01`, `edge-01`, or another measured runtime host;
- do not collapse the eight-node Seoul runtime to create a slot.

Cross-region k6 end-to-end latency includes client/network latency. Interpret it alongside
server-side evidence:

- Nginx request/upstream timing;
- Spring request metrics/traces;
- PostgreSQL statistics;
- host/runtime metrics.

### 4. Measurement before optimization

M8 may identify hypotheses, but it must not:

- add an index because a query merely looks expensive;
- introduce Redis/cache/queue;
- rewrite repositories or SQL for performance;
- resize business nodes to make baseline results look better;
- tune JVM/DB/runtime parameters merely because a metric looks high.

M9 owns evidence-supported performance changes and comparable remeasurement.

### 5. Negative results are valid

If dataset M and the representative workload do not expose a meaningful bottleneck, retain
that result.

Do not manufacture:

- an N+1 problem;
- a cache requirement;
- a PostgreSQL bottleneck;
- a saturation point;
- a latency improvement claim.

## Workload artifacts and evidence model

Repository-owned M8 implementation should provide:

1. **dataset generator**
   - deterministic fixed seed;
   - structured Program/Application fields used by the current product;
   - controlled business-like status/history distributions;
   - explicit expected row counts;
   - repeatable reset/reseed behavior.

2. **API verification subset**
   - a smaller subset created/exercised through the real API;
   - proves generated data and the deployed business boundary remain compatible.

3. **k6 workload harness**
   - authenticated sessions;
   - CSRF handling;
   - frozen API mix;
   - think time;
   - scenario-level tags with bounded cardinality;
   - no IDs/request IDs/usernames as metric labels.

4. **run manifest**
   - exact condition metadata for every retained baseline.

5. **sanitized evidence collector**
   - k6 summary;
   - relevant Grafana/Prometheus measurements;
   - selected trace references;
   - PostgreSQL `pg_stat_statements` snapshots;
   - no credentials/session values/body dumps.

Prefer a simple repository-owned implementation over a general-purpose workload platform.

## Dataset strategy

### Development dataset S

Use S to validate generation/reset logic and k6 scenario correctness quickly.

Done condition:

- deterministic regeneration from the same seed produces the same expected distribution;
- referential/state invariants hold;
- API verification subset passes.

### Baseline dataset M

M is the mandatory M8 measurement dataset.

Target:

- about 100,000 applications;
- about 400,000 history rows;
- structured program/application fields;
- attachment metadata/object population only to the extent needed by the frozen 5% file
  workload and later reconciliation observation.

Volume data may use a controlled bulk-generation path where that is materially faster than
creating every row over HTTP, but:

- schema/business invariants must remain valid;
- generation must be repository-owned and reproducible;
- a smaller verification subset must still exercise the real API;
- bulk generation is test-data preparation, not production application behavior.

### Dataset L

Do not create L automatically during the first M8 slice.

Move to L only when:

- M baseline is stable and repeatable; and
- additional scale is required to expose query/operational behavior that M does not show.

## Required measurement set

### k6 client-side

Retain at minimum:

- requests/iterations;
- success/error rate;
- throughput;
- p50/p95/p99 request duration;
- scenario/endpoint-family breakdown;
- checks/failures;
- VU profile over time.

Do not reduce interpretation to one global p95 value.

### Edge/application

Observe:

- Nginx total request timing;
- Nginx upstream timing;
- Spring request count/duration/status;
- JVM/process CPU/memory;
- GC where useful;
- thread/activity pressure;
- datasource pool usage;
- application error logs;
- representative traces for slower/error requests.

### PostgreSQL

Observe:

- active/idle connections;
- transaction activity;
- locks/deadlocks;
- checkpoints/cache/block activity exposed by the existing telemetry;
- host CPU/disk;
- `pg_stat_statements` top query families by calls and execution cost;
- block hit/read/write statistics where available.

M8 records candidates. M9 owns target SQL extraction plus
`EXPLAIN (ANALYZE, BUFFERS)` and any subsequent change.

### Garage

For attachment workload observe:

- all three node health;
- request/storage errors;
- relevant RPC/connectivity errors;
- host/storage pressure;
- capacity signals already exposed by the M7 pipeline.

## Scenarios

### W1 — workload harness smoke

Purpose: correctness of the load harness, not performance.

Profile:

- S dataset;
- 1–2 VU;
- short bounded duration;
- real public edge;
- real session/CSRF behavior;
- each workload family exercised at least once.

Must pass before any normal baseline.

### W2 — mixed normal baseline

Purpose: primary M8 baseline.

Profile:

- M dataset;
- about 30 VU;
- 15 minutes;
- frozen business mix;
- think time enabled;
- same loadgen region and runtime configuration for retained comparison runs.

Run at least twice only when necessary to establish that the result is repeatable; do not
rerun merely to obtain a prettier number.

### W3 — bounded peak baseline

Run only after W2 is healthy and evidence capture is trustworthy.

Initial profile:

- M dataset;
- about 100 VU;
- 10–15 minutes;
- same API mix/seed/loadgen region.

Purpose:

- observe whether materially different resource/query behavior appears under a plausible
  peak;
- not to prove maximum capacity.

### W4 — targeted business scenarios

Use only the targeted scenarios that materially improve later diagnosis.

Candidates:

1. **deadline submission burst**
   - weight create/save/submit around a bounded burst;
   - observe request errors/latency, DB/thread pressure, attachment path.

2. **review opening / reviewer contention**
   - concurrent reviewer queue consumption/claim attempts;
   - retain winner/conflict/duplicate-assignment/partial-side-effect counts;
   - may strengthen the existing reviewer-claim E2 evidence if the run adds representative
     scale.

3. **operational read growth**
   - repeat list/filter/page paths against dataset M;
   - observe query frequency/cost without preselecting an index fix.

Do not require every candidate to become a retained scenario. Drop scenarios that do not
produce useful evidence.

### Stress progression

The frozen progression is:

`30 -> 50 -> 100 -> 150 -> 200 VU`

Do **not** execute the full progression automatically.

Continue beyond the bounded peak only when the prior evidence makes a saturation search
useful. Record the stop reason.

## Implementation phases

### Phase 1 — Repository workload foundation

Status: **COMPLETE**

Completed boundary:

- PR #95 added the opt-in private Tokyo `loadgen-01` model, pinned k6 foundation,
  run-manifest contract, and focused static checks;
- PR #96 corrected one pre-existing ambiguous browser-E2E locator discovered by the
  post-merge run;
- final post-merge `main` baseline CI run `34862295776` at
  `b9bfff92ded572eefcdf4281d0a506a021392f72` passed.

Create repository-side foundations only.

Scope:

- add the smallest OpenTofu model required for a temporary cross-region `loadgen-01`;
- preserve all eight persistent Seoul nodes unchanged;
- add no public business service other than the existing edge path;
- define loadgen OS/runtime prerequisites;
- add the k6 workload directory/harness skeleton;
- add run-manifest format;
- add repository/static tests for:
  - default Tokyo placement;
  - no replacement/destruction of persistent Seoul nodes;
  - no k6 placement on measured business/observability hosts;
  - no secrets embedded in workload configuration;
- no live GCP apply;
- no dataset M generation;
- no performance run.

Done condition:

- exact-head CI passes;
- repository plan/fixtures prove a bounded temporary loadgen addition only;
- workload harness/config structure is reproducible and contains no secret material.

### Phase 2 — Deterministic synthetic dataset tooling

Status: **COMPLETE**

Completed boundary:

- PR #97 added fixed-seed S/M/L dataset generation, guarded M8 namespace reset/load,
  generated verification SQL, invariant checks, and the real Spring API verification subset;
- CI loaded dataset S into the migrated PostgreSQL test schema and passed generated verification;
- final post-merge `main` baseline CI run `34864808869` at
  `a1e7fec2ccefa81f08dbc2d71407e5125689a3df` passed.

Implement S/M generation and reset/verification tooling.

Done condition:

- fixed-seed S generation is deterministic;
- state/referential invariants are verified;
- real API verification subset passes;
- M generation path is defined and tested without requiring a full live benchmark yet.

### Phase 3 — Live loadgen and dataset M preparation

Status: **COMPLETE**

Live checkpoint:

- temporary Tokyo `loadgen-01` is RUNNING as `e2-standard-2` at `10.50.0.10`
  with no public access configuration;
- repository-owned loadgen configuration completed with pinned k6 `2.2.0` verification;
- deterministic dataset M seed `20260914` loaded successfully;
- retained dataset manifest SHA-256:
  `9e174ead7c9ae7b77d5adc18c93e336b4cac5e30b5962bf47c31de4f42bea696`;
- verified M8 namespace counts:
  - programs: 12;
  - users: 1,048;
  - applications: 100,000;
  - application status history: 399,990;
  - audit events: 499,990;
- deployed API verification passed against bulk program `8000000001` using real HTTPS,
  session, and CSRF behavior; a structured M8-pattern DRAFT was created and read back;
- pre-workload telemetry health passed:
  - application private probe `probe_success=1`;
  - Spring HTTP request telemetry present;
  - PostgreSQL exporter `pg_up=1`;
- no performance tuning or conclusion was made in Phase 3.

Sequence:

1. lock exact reviewed main SHA;
2. run read-only target-region quota check;
3. review exact OpenTofu plan;
4. apply only the reviewed temporary loadgen delta;
5. configure `loadgen-01`;
6. generate/reset dataset M;
7. verify expected data counts/invariants;
8. run the API verification subset;
9. confirm M7 telemetry remains healthy before workload measurement.

No performance conclusion yet.

### Phase 4 — Smoke and normal baseline

Status: **COMPLETE**

W1 correctness smoke and W2 normal baseline are complete.

W1:

- run `m8-w1-20260914T181710Z-faf46c4c`;
- dataset S / seed `20260914`;
- real HTTPS/session/CSRF boundary;
- all frozen workload families exercised successfully;
- correctness evidence only.

W2:

- run `m8-w2-20260914T203329Z-ac3d7657`;
- dataset M / seed `20260914`;
- 30 VU / 15 minutes;
- 26,864 business requests;
- observed mix 40.02/14.98/9.98/20.00/10.01/5.00;
- non-file success 100.0000%;
- non-file p95 222.197 ms;
- internal regression target PASS;
- Hikari pending 0;
- db-01 CPU average about 36.7%, max about 52.8%;
- reviewer queue result/count SQL means 100.136/67.933 ms.

W2 established a healthy normal-load baseline and identified reviewer queue SQL as the first
measured database candidate without showing general saturation.

### Phase 5 — Peak and targeted scenario evidence

Status: **COMPLETE**

W3 bounded peak was executed in three steps:

1. the first 100-VU attempt aborted after a support-path timeout triggered a global harness
   abort; retained as harness diagnostic evidence only;
2. a hardened 100 closed-VU / 10-minute run completed and exposed sustained DB/pool
   saturation, but the delivered business mix diverged under saturation;
3. the final retained W3 changed only load generation to independent
   `constant-arrival-rate` scenarios with the frozen offered mix.

Final W3:

- run `m8-w3-20260915T021822Z-d6c30508`;
- dataset M / seed `20260914`;
- 10 minutes;
- offered 100 business requests/s at 40/15/10/20/10/5;
- hard 100-VU ceiling;
- 17,336 completed iterations;
- 15,668 dropped iterations, about 47.5% of scheduled iterations;
- 29,814 completed business requests, about 49.7 requests/s;
- non-file business success among executed requests 100.0000%;
- non-file p95 2,067.479 ms;
- internal regression target FAIL;
- support-path error rate about 6.07%.

Correlated W3 telemetry:

- Hikari active average about 8.61, max 10;
- Hikari pending average about 39.52, max 54;
- db-01 CPU average about 90.94%, max about 99.98%;
- PostgreSQL deadlocks 0;
- edge-01 CPU average about 3.49%, max about 6.07%;
- private application probe remained 1;
- edge listen overflow/drop remained 0.

W3 query means:

- applicant list 215.726 ms;
- reviewer queue result 417.049 ms;
- reviewer queue count 305.405 ms.

W4 and 150/200-VU stress were not executed. Dataset M plus W3 already produced a repeatable,
material saturation signal and concrete SQL candidates. Additional load would add less
diagnostic value than M9 query-plan analysis and same-condition remeasurement.

### Phase 6 — M8 evidence closeout

Status: **COMPLETE**

Closeout outputs:

- sanitized evidence retained in `docs/operations/M8_WORKLOAD_EVIDENCE.md`;
- exact W1/W2/W3 dataset, source, release, manifest, workload, and runtime identities retained;
- invalid/diagnostic W3 attempts retained separately rather than hidden;
- PostgreSQL query bottleneck candidate promoted to E3 with
  `docs/portfolio/M8_POSTGRESQL_QUERY_BOTTLENECK_EVIDENCE.md`;
- strongest M9 candidates ranked as reviewer queue result/count first and applicant-list SQL
  second;
- negative findings retained: no edge saturation, no deadlocks, no memory pressure, private
  application probe remained healthy;
- no index/query/cache/pool/runtime optimization was implemented in M8;
- final runtime OpenTofu plan reported no changes with the retained `storage-03` overrides
  and `enable_loadgen=true`;
- temporary Tokyo `loadgen-01` remains retained through M9 for comparable remeasurement;
  M9 closeout owns its destruction/lifecycle decision.

M9 must begin from measured SQL and plan evidence:

1. extract the exact reviewer queue and applicant-list SQL;
2. run `EXPLAIN (ANALYZE, BUFFERS)` under controlled conditions;
3. compare the smallest evidence-supported alternatives;
4. implement only justified changes;
5. rerun equivalent W2/W3 conditions before claiming improvement.

## Files/components expected

Likely implementation areas:

- `infra/opentofu/` for temporary cross-region loadgen resources;
- `config/ansible/` for loadgen configuration if needed;
- `workload/` or `scripts/workload/` for deterministic dataset/k6 tooling;
- `docs/operations/` for sanitized M8 runtime evidence;
- `docs/portfolio/PORTFOLIO_EVIDENCE_MAP.md` when maturity changes;
- `docs/AI_PROJECT_STATE.md`;
- this active plan.

Do not modify business-domain behavior merely to simplify workload generation.

## CI and verification

Every M8 implementation PR must preserve existing required checks.

Add only focused M8 checks needed for the slice, such as:

- static temporary-loadgen placement contract;
- k6 script syntax/static validation;
- deterministic generator tests;
- no-secret/high-cardinality-label checks;
- run-manifest validation.

No M8 PR merges from a failing exact head.

Live GCP execution occurs only after the exact repository boundary is reviewed and merged.

## Evidence treatment

M8 primarily creates E3 representative measurement evidence.

M8 does not automatically make a primary portfolio story.

Possible outcomes include:

- a real PostgreSQL/query candidate for M9;
- a real attachment/storage candidate;
- representative reviewer-contention evidence;
- no meaningful bottleneck at dataset M / normal load.

All are valid if retained factually.

Do not raise evidence maturity because k6 exists or because a dashboard shows data.

## Completion criteria

M8 is complete only when:

- deterministic S/M synthetic data tooling exists;
- dataset M has been generated and verified live;
- separate cross-region load generation is reproducible;
- workload security/session/CSRF behavior matches the real deployed boundary;
- W1 smoke passes;
- W2 normal baseline is retained with exact run metadata;
- server/client/DB/storage evidence is correlated sufficiently for later diagnosis;
- W3/W4/stress are executed only as justified and their stop/continue reasons are recorded;
- at least one `pg_stat_statements` baseline snapshot is retained;
- candidate bottlenecks are evidence-based rather than predetermined;
- no M9 optimization was pulled into M8;
- sanitized evidence is committed;
- runtime/loadgen lifecycle disposition is explicit;
- final exact-head CI passes;
- post-merge `main` CI passes.

M9 must not begin with a chosen solution. It begins from the strongest measured M8
candidate, or records that no worthwhile optimization candidate was found.
