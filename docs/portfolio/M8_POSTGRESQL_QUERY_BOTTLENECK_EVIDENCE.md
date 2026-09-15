# Evidence Card — PostgreSQL read-path saturation under representative peak load

Status: BASELINE RETAINED  
Milestone: M8  
Evidence maturity: E3  
Source release SHA: `d6c30508eed79fbc6dfc67de07ce0099817f3a60`

## Context / assumption

The application-review workload includes applicant list/detail reads and reviewer queue reads
over a growing application table. Before M8, these paths were only candidates; no
representative measurement proved that they were material.

M8 used deterministic dataset M (100,000 applications), a separate Tokyo load generator,
the deployed HTTPS/session/CSRF boundary, and the existing M7 telemetry substrate.

## Problem

The valid W2 normal baseline was healthy, but the bounded W3 offered-load peak exposed a
repeatable saturation condition.

At 100 offered business requests/s with a hard 100-VU ceiling:

- 17,336 iterations completed;
- 15,668 iterations were dropped;
- about 47.5% of scheduled iterations could not start within the VU ceiling;
- completed business throughput was about 49.7 requests/s;
- non-file p95 was 2,067.479 ms and the internal regression target failed.

The private application probe remained healthy, so this is not recorded as a total service
outage.

## Baseline

### W2 normal load

- dataset: M / seed `20260914`;
- source: `ac3d7657f533f70126d12773c8b27f2c5b40b38e`;
- profile: 30 VU / 15 minutes;
- business requests: 26,864;
- frozen mix preserved;
- non-file success: 100%;
- non-file p95: 222.197 ms;
- Hikari pending: 0;
- db-01 CPU: average about 36.7%, max about 52.8%.

Database means:

- applicant list: 30.784 ms;
- reviewer queue result: 100.136 ms;
- reviewer queue count: 67.933 ms.

### W3 bounded offered load

- run: `m8-w3-20260915T021822Z-d6c30508`;
- dataset: M / seed `20260914`;
- source: `d6c30508eed79fbc6dfc67de07ce0099817f3a60`;
- profile: 10 minutes, offered 100 business requests/s, hard 100-VU ceiling;
- frozen offered mix: 40/15/10/20/10/5;
- completed business requests: 29,814;
- dropped iterations: 15,668;
- non-file p95: 2,067.479 ms;
- support-path error rate: about 6.07%.

Database means:

- applicant list: 215.726 ms;
- reviewer queue result: 417.049 ms;
- reviewer queue count: 305.405 ms.

Runtime correlation:

- Hikari active: average about 8.61, max 10;
- Hikari pending: average about 39.52, max 54;
- db-01 CPU: average about 90.94%, max about 99.98%;
- PostgreSQL deadlocks: 0;
- edge-01 CPU: average about 3.49%, max about 6.07%;
- edge listen overflow/drop: 0;
- private application probe: 1 throughout.

## Analysis

The evidence narrows the performance problem to database work and datasource-pool waiting
rather than edge capacity, memory pressure, or deadlocks.

The reviewer queue remains the strongest route-specific candidate because its result and
count statements are expensive at both W2 and W3. Under W3 saturation, applicant-list cost
also rises materially and contributes the largest single total execution time in the
retained `pg_stat_statements` snapshot.

Compared with W2, mean execution time increased approximately:

- applicant list: 7.0x;
- reviewer queue result: 4.2x;
- reviewer queue count: 4.5x.

This evidence does not identify the exact execution-plan defect. M8 therefore stops before
claiming a missing index, bad join strategy, incorrect pool size, or cache requirement.

## Options considered

1. Increase Hikari pool size in M8.
   - Rejected. Pool waiting is observed, but increasing concurrency against a nearly
     saturated DB could worsen pressure and would not explain query cost.

2. Add an index or rewrite SQL immediately.
   - Rejected. No retained `EXPLAIN (ANALYZE, BUFFERS)` evidence exists yet.

3. Introduce Redis/cache.
   - Rejected. The measured problem does not justify new cache invalidation and operational
     complexity before simpler database/query changes are evaluated.

4. Run additional W4 or 150/200-VU stress scenarios.
   - Rejected for M8. Dataset M and W3 already expose a stable material limit and concrete
     SQL candidates; further load adds less value than query-plan diagnosis.

5. Carry the measured candidates into M9.
   - Accepted.

## Decision / action

M8 makes no performance change.

The measured handoff to M9 is:

1. reviewer queue result and count SQL as the strongest route-specific candidate;
2. applicant-list SQL as the second candidate because it becomes material under saturation;
3. Hikari pending and DB CPU as correlated saturation signals, not independent tuning
   targets.

M9 must begin with exact SQL extraction and
`EXPLAIN (ANALYZE, BUFFERS)`, compare alternatives, implement only evidence-supported
changes, and rerun equivalent W2/W3 conditions.

## Verification

The saturation pattern was observed first in a completed 100 closed-VU diagnostic and then
reproduced after changing only the load-generation model to fixed arrival rates.

The final open-model run preserved the same dataset, deployed application releases,
security boundary, loadgen region, duration class, and 100-VU ceiling. It again showed:

- DB CPU near saturation;
- sustained Hikari pending;
- increased applicant/reviewer read-query cost;
- low edge utilization;
- no deadlocks;
- application probe availability.

This is E3 representative measurement. No optimization has yet been revalidated, so the
evidence is not E4.

## Trade-off / limit

- Cross-region client latency is included in k6 end-to-end timing.
- Spring histogram buckets were unavailable, so server-side p95 was not reconstructed from
  Prometheus.
- M8 did not retain query plans; M9 owns plan-level diagnosis.
- The 100-VU ceiling is a bounded project experiment, not a production capacity claim.
- The internal p95 target is a project regression criterion, not an SLA/SLO.
- `loadgen-01` remains temporarily retained through M9 for same-condition remeasurement.

## Repository evidence

- code/config: `workload/k6/w3-peak.js`, `workload/run-w3.sh`
- migration: PostgreSQL `pg_stat_statements` enablement retained from M7
- focused tests: `scripts/workload/test-m8-workload-foundation.py`
- workload/experiment: `docs/operations/M8_WORKLOAD_EVIDENCE.md`
- diagnostic history:
  `docs/operations/M8_W3_ABORTED_DIAGNOSTIC.md`,
  `docs/operations/M8_W3_CLOSED_VU_SATURATION.md`
- CI: exact-head checks for the retained W3 harness changes
- runtime/query evidence: retained W2/W3 `pg_stat_statements` snapshots and M7 Prometheus
  telemetry summarized in the M8 evidence record

## Portfolio claim

Using a deterministic 100,000-application dataset and repeatable mixed workload, I isolated
a peak-load bottleneck to PostgreSQL read-query cost and datasource-pool waiting, retained
the baseline evidence, and deferred the actual optimization until query-plan analysis could
be performed under the same conditions.
