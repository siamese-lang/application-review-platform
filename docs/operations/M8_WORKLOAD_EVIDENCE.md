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

Next evidence boundary:

- correlate the valid W2 run with M7 Nginx/Spring/JVM/PostgreSQL/Garage/host telemetry;
- decide from correlated evidence whether W3 or a targeted W4 adds useful information;
- do not tune the reviewer query, add indexes, resize nodes, or begin M9 during this step.
