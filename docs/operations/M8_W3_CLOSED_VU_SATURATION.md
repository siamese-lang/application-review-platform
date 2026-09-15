# M8 W3 closed-VU saturation diagnostic

Status: completed diagnostic run; not the retained offered-mix W3 baseline.

Run identity:

- source: `5de92b5aef5dda744d90c7694a3f667dac1b1d2f`
- run ID: `m8-w3-20260915T014105Z-5de92b5a`
- dataset: M / seed 20260914
- loadgen: Tokyo `loadgen-01`
- profile: 100 closed VUs / 10 minutes
- application, database, and infrastructure performance configuration: unchanged from W2

Client result:

- business requests: 29,070
- non-file success: 100.0000%
- non-file p95: 1,991.346 ms
- internal regression target: FAIL
- support requests: 9,218
- support error rate: 7.8108% (about 92.19% support success)

Observed delivered business mix:

- list/detail: 55.81%
- create/save: 1.34%
- submit/resubmit: 12.93%
- reviewer queue/detail: 15.91%
- review action: 12.99%
- attachment: 1.02%

The frozen target was 40/15/10/20/10/5. The delivered mix therefore diverged materially.

Per-family latency:

- list/detail: avg 876.722 ms, p95 1,972.145 ms
- create/save: avg 675.696 ms, p95 1,741.259 ms
- submit/resubmit: avg 696.507 ms, p95 1,752.069 ms
- reviewer queue/detail: avg 1,031.478 ms, p95 2,303.859 ms
- review action: avg 697.370 ms, p95 1,742.732 ms
- attachment: avg 663.213 ms, p95 1,759.778 ms

PostgreSQL snapshot:

- applicant list: 8,112 calls, 208.700 ms mean
- reviewer queue result: 2,312 calls, 387.165 ms mean
- reviewer queue count: 2,312 calls, 289.860 ms mean
- applicant count: 8,112 calls, 11.358 ms mean

Compared with the valid W2 baseline, the first three means increased about 6.8x, 3.9x,
and 4.3x respectively.

Correlated 10-minute telemetry:

- application request rate: avg about 56.1/s, max about 86.8/s
- Hikari active: avg about 8.36, max 10
- Hikari pending: avg about 36.18, max 55
- PostgreSQL backends: avg about 13.05, max 18
- PostgreSQL deadlocks: 0
- db-01 CPU: avg about 89.47%, max about 99.98%
- app-01 CPU: avg about 18.15%, max about 37.94%
- edge-01 CPU: avg about 3.17%, max about 5.62%
- private application probe: 1 throughout
- edge listen overflow/drop: 0 throughout

Interpretation:

- database pressure is sustained rather than a short spike;
- the application connection pool is saturated for meaningful portions of the run;
- the edge tier is not the measured bottleneck;
- reviewer queue remains expensive, while saturation also amplifies applicant-list cost;
- the closed-VU executor reduces iteration throughput differently by scenario under
  saturation, so the delivered business mix no longer represents the frozen workload mix.

Disposition:

- retain this run as saturation diagnostic evidence;
- do not use it as the final frozen-mix W3 baseline;
- change only the load-generation model to independent constant-arrival-rate scenarios;
- preserve the same dataset, real session/CSRF boundary, 10-minute duration, and 100-VU
  ceiling;
- measure inability to sustain offered load as dropped iterations instead of allowing
  scenario throughput to silently change the intended mix;
- perform no M9 optimization during this transition.
