# WORKLOAD — M0 Frozen Baseline

Status: FROZEN

## Synthetic datasets

- S: about 10,000 applications for development
- M: about 100,000 applications and 400,000 history rows for baseline tests
- L: about 500,000 applications and 2,000,000 history rows for performance tests

One million applications is optional only if L fails to expose meaningful behavior. Synthetic generation uses a fixed seed and controlled business-like distributions. Volume data may be bulk-generated; a smaller verification subset must exercise real application APIs.

## Initial workload mix

- application list/detail: 40%
- create/save: 15%
- submit: 10%
- reviewer list/detail: 20%
- approve/reject/request revision: 10%
- attachment upload/download: 5%

Include think time. `k6` runs from separate `loadgen-01` and enters through public `edge-01` rather than consuming application-host resources.

## Test progression

- Smoke: 1–2 VU
- Normal baseline: about 30 VU for 15 minutes on M
- Peak: about 100 VU for 10–15 minutes
- Stress: 30 → 50 → 100 → 150 → 200 and continue only as evidence requires
- Limited soak later

Initial internal regression target for non-file HTTP traffic: success ≥ 99% and p95 < 500 ms. This is a project acceptance target, not a real customer SLA.

## Performance evidence rule

A performance milestone requires a measured problem, observation, bottleneck hypothesis, supporting evidence, a specific change, and a repeat test under the same dataset, seed, workload, duration, and infrastructure conditions.

## Reliability scenarios

Fixed before project completion:

- R1 Application process failure
- R2 PostgreSQL failure during normal workload
- R3 Garage node failure in the three-node cluster
- R4 Bad deployment and rollback
- R5 Logical DB corruption followed by PITR

Do not add endless fault scenarios before these are completed.
