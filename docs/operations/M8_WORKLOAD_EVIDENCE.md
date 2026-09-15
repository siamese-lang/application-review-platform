# M8 Workload — Live Evidence

Status: ACTIVE / W1 VERIFIED / W2 BASELINE VERIFIED  
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
