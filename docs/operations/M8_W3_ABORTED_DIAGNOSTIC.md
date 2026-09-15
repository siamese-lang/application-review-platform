# M8 W3 first-attempt diagnostic

Status: diagnostic only; not the retained W3 baseline.

Run:

- source: `1c40ca3fe84a9ceea0ce53198b211d6901d7d300`
- run ID: `m8-w3-20260915T010505Z-1c40ca3f`
- dataset: M / seed 20260914
- target: 100 VU / 10 minutes
- actual: about 30 seconds before global harness abort

Observed failure:

- three support CSRF requests returned status 0 with `dial: i/o timeout`;
- the W3 script globally aborted on the support failure;
- 100 iterations were interrupted;
- HTTP failures were 3 / 1,702 (0.17%).

The short-window latency metrics are not a valid retained W3 regression result.

Correlated runtime evidence:

- private application probe remained 1;
- edge-01 CPU max about 6.8%;
- edge listen overflow/drop: 0;
- edge network drops: 0;
- Hikari active max 10;
- Hikari pending max 54;
- PostgreSQL backends max 18;
- db-01 CPU max about 94.9%;
- app-01 CPU max about 69.2%;
- memory pressure remained low.

Immediate post-abort pg_stat_statements snapshot:

- reviewer queue result: 114 calls, 301.839 ms mean;
- reviewer queue count: 114 calls, 200.469 ms mean;
- applicant application list: 288 calls, 87.083 ms mean.

Relative to W2, those means rose about 3.0x, 3.0x, and 2.8x. The three statements account
for about 98% of execution time in the retained top-20 snapshot.

Interpretation:

- evidence points to application/database pressure, not edge saturation;
- reviewer queue remains the largest single query family;
- at 100 VU the pressure also spreads to applicant-list reads as connection-pool waiters
  and DB CPU increase;
- no application, DB, or infrastructure tuning is justified inside M8.

Next boundary:

- change only W3 support-failure handling so transient support failures are measured rather
  than globally aborting the whole run;
- rerun the same dataset M / 100 VU / 10-minute profile;
- retain the completed run before deciding whether W4 adds useful evidence.
