# WORKLOAD — M0 Baseline amended by ADR-001

Status: FROZEN EXCEPT AS AMENDED BY ACCEPTED ADRS

## Synthetic datasets

- S: about 10,000 applications for development
- M: about 100,000 applications and 400,000 history rows for baseline tests
- L: about 500,000 applications and 2,000,000 history rows for performance tests

One million applications is optional only if L fails to expose meaningful behavior. Synthetic generation uses a fixed seed and controlled business-like distributions. Volume data may be bulk-generated; a smaller verification subset must exercise the real `/api/v1` application/review path.

Synthetic data after M5 should populate the structured program/application fields introduced for the final product surface rather than filling only generic title/content values.

## Initial workload mix

The workload percentages remain business-operation oriented and are retargeted from server-rendered pages to the final API boundary:

- application/program list/detail API: 40%
- create/save application API: 15%
- submit/resubmit API: 10%
- reviewer queue/detail API: 20%
- start/approve/reject/request-revision API: 10%
- attachment upload/download API: 5%

Include think time. `k6` runs from separate `loadgen-01` and enters through public `edge-01` rather than consuming application-host resources.

The React static asset path is not the primary performance target. Static asset delivery may be checked separately, while business performance measurements focus on edge → API → PostgreSQL/Garage behavior.

## Test progression

- Smoke: 1–2 VU
- Normal baseline: about 30 VU for 15 minutes on M
- Peak: about 100 VU for 10–15 minutes
- Stress: 30 → 50 → 100 → 150 → 200 and continue only as evidence requires
- Limited soak later

Initial internal regression target for non-file API traffic: success ≥ 99% and p95 < 500 ms. This is a project acceptance target, not a real customer SLA.

## Session/CSRF workload handling

Browser-like k6 scenarios that modify protected resources must establish an authenticated session and obtain/use the same CSRF mechanism implemented for the SPA. Do not bypass security in performance tests simply to generate load.

Read-only diagnostic loads may target selected endpoints without browser rendering when explicitly documented.

## Performance evidence rule

A performance milestone requires a measured problem, observation, bottleneck hypothesis, supporting evidence, a specific change, and a repeat test under the same dataset, seed, API workload, duration, and infrastructure conditions.

Later analysis follows: k6/Grafana/trace → `pg_stat_statements` → target SQL → `EXPLAIN (ANALYZE, BUFFERS)` → change → same-data/same-workload remeasurement.

## Reliability scenarios

Fixed before project completion:

- R1 Application process failure
- R2 PostgreSQL failure during normal workload
- R3 Garage node failure in the three-node cluster
- R4 Bad deployment and rollback, including frontend/backend release consistency where relevant
- R5 Logical DB corruption followed by PITR

Do not add endless fault scenarios before these are completed.
