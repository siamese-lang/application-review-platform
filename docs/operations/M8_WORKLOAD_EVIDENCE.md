# M8 Workload — Live Evidence

Status: COMPLETE / W1 VERIFIED / W2 BASELINE VERIFIED / W3 PEAK VERIFIED  
Last updated: 2026-09-15 UTC

This record contains sanitized M8 workload evidence. It intentionally omits passwords,
session/CSRF material, OS Login keys, decrypted SOPS content, request bodies containing
credentials, and other secret material.

## W1 — workload harness smoke

Purpose: prove workload-harness correctness through the real deployed boundary. W1 is not
performance evidence.

Verified live run:

- run ID: `m8-w1-20260914T181710Z-faf46c4c`;
- workload source SHA: `faf46c4c8256c9921a7aa6da37902b2d3dc53dbf`;
- backend/API release SHA:
  `cea4ca09d05efd89bcb9227c866d841968c08547`;
- frontend release SHA:
  `549511b0a8af9582125e89aaa2bde7fc4bffcd6d`;
- dataset: S, seed `20260914`;
- dataset manifest SHA-256:
  `b6d964b5bb482ed3ec241e2292b8e98b9d3fc19d7a3e8a2394266288f96a5191`;
- load generator: private Tokyo `loadgen-01`, k6 `2.2.0`;
- profile: 1 VU, 1 iteration, 2-minute maximum;
- observed completion: one iteration in about 5.2 seconds;
- result: PASS.

The successful business flow exercised:

- list/detail;
- create/save;
- submit and resubmit;
- reviewer queue/detail;
- review start, revision request, restart, and approval;
- attachment upload, byte-identical download, and cleanup;
- real HTTPS, session, and CSRF handling.

The 5.2-second completion time is retained only as run context. It is not a throughput,
latency, SLA, SLO, or performance claim.

Two runner defects were exposed before the successful run and corrected rather than hidden:

1. k6 attachment fixture resolution needed to be relative to the script directory;
2. the live runtime legitimately had different backend/frontend component release SHAs, so
   W1 now records both instead of imposing a false equality requirement.

## W2 — mixed normal baseline

Status: VERIFIED LIVE BASELINE.

Retained valid run:

- run ID: `m8-w2-20260914T203329Z-ac3d7657`;
- workload source SHA: `ac3d7657f533f70126d12773c8b27f2c5b40b38e`;
- backend/API release SHA:
  `cea4ca09d05efd89bcb9227c866d841968c08547`;
- frontend release SHA:
  `549511b0a8af9582125e89aaa2bde7fc4bffcd6d`;
- dataset: M, seed `20260914`;
- dataset manifest SHA-256:
  `9e174ead7c9ae7b77d5adc18c93e336b4cac5e30b5962bf47c31de4f42bea696`;
- deterministic interactive overlay SHA-256:
  `f93dfb6a030fa552de3dd4c7b9c022368079680bf2b16b13c05883e8b678aae1`;
- load generator: private Tokyo `loadgen-01`, k6 `2.2.0`;
- profile: 30 VU, 15 minutes, frozen 40/15/10/20/10/5 business mix;
- completed iterations: 14,773;
- total business requests: 26,864;
- non-file success rate: 100.0000%;
- non-file p95: 222.197 ms;
- internal non-file regression target: PASS.

Observed business mix:

- list/detail: 10,752 requests, 40.02%, target 40%;
- create/save: 4,024 requests, 14.98%, target 15%;
- submit/resubmit: 2,682 requests, 9.98%, target 10%;
- reviewer queue/detail: 5,374 requests, 20.00%, target 20%;
- review actions: 2,688 requests, 10.01%, target 10%;
- attachment upload/download: 1,344 requests, 5.00%, target 5%.

All six business families recorded zero workload-check errors in the retained run.

Client-side family latency:

- list/detail: average 66.825 ms, p95 128.613 ms, p99 151.874 ms;
- create/save: average 48.875 ms, p95 57.611 ms, p99 68.532 ms;
- submit/resubmit: average 48.824 ms, p95 53.321 ms, p99 59.815 ms;
- reviewer queue/detail: average 132.432 ms, p95 329.024 ms, p99 374.668 ms;
- review actions: average 49.216 ms, p95 55.730 ms, p99 64.923 ms;
- attachment: average 73.249 ms, p95 124.023 ms, p99 156.293 ms.

The strongest W2 database candidate is the reviewer queue path. The retained
`pg_stat_statements` snapshot shows:

- reviewer queue result query: 2,687 calls, 269,066.616 ms total execution time,
  100.136 ms mean execution time;
- reviewer queue count query: 2,687 calls, 182,535.186 ms total execution time,
  67.933 ms mean execution time.

These two statements dominate the retained database execution-cost snapshot and align with
the reviewer queue/detail family being the slowest client-side family. This is a candidate
for later diagnosis, not an M8 optimization decision. M9 owns query-plan analysis and any
index/query change after server-side telemetry correlation is complete.

Two invalid W2 attempts are retained as harness-validation history rather than performance
evidence:

1. the first attempt stopped before k6 measurement because SQL passed through SSH
   `psql -c` lost shell quoting; SQL is now sent over stdin;
2. a later 15-minute attempt revealed that k6 resets its cookie jar between VU iterations by
   default. W2 cached authentication state while the session cookie was discarded, so only
   each VU's first iteration succeeded. The harness now sets `noCookiesReset: true`.
   That attempt must not be used as a system performance baseline.

The same invalid run exposed that pinned k6 `2.2.0` legacy `--summary-export` places
metric fields directly under each metric object rather than under a `values` wrapper. The
runner parser was corrected before the retained valid W2 run.

### W2 server-side telemetry correlation

The retained W2 client/database result was correlated against the existing M7 Prometheus
telemetry for the workload window (approximately 2026-09-14 20:33Z through 20:49Z).

Spring HTTP histogram buckets were not present for this runtime, so a server-side p95 could
not be reconstructed from Prometheus. The existing request count/sum series still provide a
rate-derived mean-duration comparison. During the W2 window:

- `/api/v1/review/applications` was the slowest material business route, with the
  rate-derived server mean averaging about 177 ms across the sampled window and peaking
  around 501 ms;
- this aligns with the client-side reviewer queue/detail family being the slowest family
  (132.432 ms average, 329.024 ms p95);
- the reviewer queue result and count SQL statements averaged 100.136 ms and 67.933 ms
  respectively in the same reset `pg_stat_statements` interval.

The current evidence therefore points to query work in the reviewer queue path rather than
a general application/runtime saturation condition. This remains a diagnosis candidate,
not an optimization decision.

No material saturation/failure signal appeared in the correlated telemetry:

- Hikari active connections: average about 1.12, maximum 5;
- Hikari pending connections: 0 throughout;
- PostgreSQL backends for `arp`: 12 to 13;
- PostgreSQL deadlocks: 0;
- PostgreSQL cache-hit ratio: about 96.6% to 99.5%;
- db-01 CPU: average about 36.7%, maximum about 52.8%;
- app-01 CPU: average about 15.1%, maximum about 38.2%;
- app-01 memory used: about 27.4% to 27.8%;
- db-01 memory used: about 19.4% to 20.8%;
- edge and storage CPU remained low;
- private application probe stayed at `probe_success=1` for the full sampled window.

Lock counts were transiently present under the mixed read/write workload, but no deadlocks
or connection-pool waiting accompanied them. The W2 evidence does not support a global CPU,
memory, connection-pool, storage, or availability bottleneck.

W2 conclusion:

- normal load is healthy under the frozen M profile and 30-VU mixed workload;
- reviewer queue/query cost is the strongest measured M9 candidate so far;
- W3 bounded peak is justified to determine whether materially different behavior appears
  at 100 VU before M8 is closed or a targeted W4 is selected;
- no index/query/runtime change is made in M8.

## W3 — bounded peak / offered-load baseline

Status: VERIFIED LIVE PEAK EVIDENCE.

Two earlier W3 attempts are retained separately as harness/diagnostic history:

- `docs/operations/M8_W3_ABORTED_DIAGNOSTIC.md`: first 100-VU attempt aborted after
  support-path dial timeouts triggered a global harness abort;
- `docs/operations/M8_W3_CLOSED_VU_SATURATION.md`: 100 closed VUs completed for 10 minutes
  and exposed sustained DB/pool saturation, but the delivered business mix diverged because
  slower scenarios completed fewer iterations.

The final retained W3 run changed only the load-generation model to independent
`constant-arrival-rate` scenarios. Application, database, infrastructure, dataset, and
security behavior were unchanged.

Retained run identity:

- run ID: `m8-w3-20260915T021822Z-d6c30508`;
- workload source SHA: `d6c30508eed79fbc6dfc67de07ce0099817f3a60`;
- backend/API release SHA: `cea4ca09d05efd89bcb9227c866d841968c08547`;
- frontend release SHA: `549511b0a8af9582125e89aaa2bde7fc4bffcd6d`;
- dataset: M, seed `20260914`;
- dataset manifest SHA-256:
  `9e174ead7c9ae7b77d5adc18c93e336b4cac5e30b5962bf47c31de4f42bea696`;
- deterministic overlay SHA-256:
  `f93dfb6a030fa552de3dd4c7b9c022368079680bf2b16b13c05883e8b678aae1`;
- load generator: private Tokyo `loadgen-01`, k6 `2.2.0`;
- duration: 10 minutes;
- offered business load: 100 requests/s at frozen 40/15/10/20/10/5 mix;
- hard scenario VU ceiling: 100 total.

Capacity outcome:

- completed iterations: 17,336;
- dropped iterations: 15,668;
- scheduled plus dropped iterations: 33,004, consistent with the intended arrival schedule;
- dropped-iteration share: about 47.5%;
- completed business requests: 29,814, about 49.7 requests/s;
- non-file business success rate among executed requests: 100.0000%;
- non-file p95: 2,067.479 ms;
- internal regression target: FAIL;
- support requests: 11,859;
- support-path error rate: about 6.07%;
- HTTP request failure rate: about 1.73%.

The completed-request mix was 45.06/12.49/11.46/19.63/8.12/3.24. Unlike the closed-VU
diagnostic, this is not interpreted as the offered workload changing: each scenario retained
its configured arrival rate and fixed VU ceiling, and overload surfaced as
`dropped_iterations`.

Client-side family latency:

- list/detail: average 929.240 ms, p95 1,999.511 ms, p99 2,537.484 ms;
- create/save: average 753.641 ms, p95 1,762.127 ms, p99 2,248.994 ms;
- submit/resubmit: average 842.671 ms, p95 1,902.165 ms, p99 2,327.386 ms;
- reviewer queue/detail: average 1,122.995 ms, p95 2,413.960 ms, p99 3,047.314 ms;
- review actions: average 776.802 ms, p95 1,777.605 ms, p99 2,477.681 ms;
- attachment: average 734.632 ms, p95 1,945.873 ms, p99 2,416.727 ms.

The reset `pg_stat_statements` snapshot identifies three dominant read statements:

- applicant list: 6,717 calls, 1,449,031.906 ms total, 215.726 ms mean;
- reviewer queue result: 2,926 calls, 1,220,284.117 ms total, 417.049 ms mean;
- reviewer queue count: 2,926 calls, 893,613.734 ms total, 305.405 ms mean.

Compared with W2, their mean execution times increased from 30.784/100.136/67.933 ms to
215.726/417.049/305.405 ms, approximately 7.0x/4.2x/4.5x.

### W3 server-side telemetry correlation

During the final W3 window:

- application request rate averaged about 59.7/s and peaked about 134.0/s;
- Hikari active connections averaged about 8.61 and peaked at the configured pool size 10;
- Hikari pending connections averaged about 39.52 and peaked at 54;
- PostgreSQL backends averaged about 13.96 and peaked at 19;
- PostgreSQL deadlocks remained 0;
- db-01 CPU averaged about 90.94% and peaked about 99.98%;
- app-01 CPU averaged about 18.83% and peaked about 41.81%;
- edge-01 CPU averaged about 3.49% and peaked about 6.07%;
- memory pressure remained low on app/db/edge/storage;
- the private application probe remained `1`;
- edge listen overflow/drop remained `0`.

This reproduces the closed-VU diagnostic pattern under the corrected offered-load model:
database CPU and application datasource-pool waiting are sustained, while edge capacity,
memory, deadlocks, and application availability do not show the same saturation signal.

The evidence supports a database-work/query-cost performance investigation in M9. It does
not yet prove a specific missing index, query rewrite, pool-size change, cache, or other
solution.

## W4 / stress disposition

No W4 targeted scenario and no 150/200-VU stress progression were executed.

Reason:

- dataset M plus the bounded W3 already produced a material and repeatable saturation signal;
- reviewer queue SQL and applicant-list SQL are already measurable candidates for M9;
- edge/storage availability did not emerge as the limiting factor;
- a further mixed or targeted workload would add less diagnostic value than M9 query-plan
  analysis with `EXPLAIN (ANALYZE, BUFFERS)` followed by same-condition remeasurement.

Stopping here avoids manufacturing additional scenarios after the milestone question has
already been answered.

## M8 closeout

Final runtime OpenTofu plan, using the retained `storage-03` overrides and
`enable_loadgen=true`, reported:

`No changes. Your infrastructure matches the configuration.`

Temporary `loadgen-01` remains intentionally retained through M9 because M9 requires the
same isolated Tokyo load-generator boundary for comparable before/after measurements. Its
destruction/lifecycle decision moves to M9 closeout.

M8 conclusion:

- normal 30-VU load is healthy and meets the internal regression target;
- the bounded offered-load peak does not sustain 100 business requests/s within the
  100-VU ceiling and drops about 47.5% of scheduled iterations;
- DB CPU saturation and Hikari waiting correlate with materially increased read-query cost;
- reviewer queue result/count remain the strongest route-specific M9 candidate, with
  applicant list also becoming material under saturation;
- no performance change was made in M8.

