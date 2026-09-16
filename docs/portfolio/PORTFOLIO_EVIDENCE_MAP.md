# Portfolio Evidence Map

Status: ACTIVE PROJECT CONTROL

This document prevents the project from becoming a technology checklist. The final portfolio should normally promote only 2–3 primary problem-solving stories.

A technology is not a portfolio claim by itself. A milestone is not a portfolio claim by itself.

## Evidence maturity

- E0 — hypothesis only: plausible problem/risk, not demonstrated.
- E1 — implemented: code/config exists, behavior not independently proven.
- E2 — correctness verified: focused integration/concurrency/E2E evidence proves an invariant or failure mode.
- E3 — representative measurement: controlled dataset/workload/operational experiment has measured the behavior.
- E4 — change revalidated: a specific change was compared against the same or equivalent baseline conditions.
- E5 — portfolio-ready: problem → analysis → decision → action → verification → trade-off is retained with repository evidence.

E5 does not require a performance percentage in every case. Concurrency, delivery, reliability, and recovery may be proven by invariants, failure outcomes, exact artifact identity, rollback/recovery success, or elapsed recovery measurements. Never invent numbers or convert an architectural intention into an achieved result.

## Primary-story budget

M12 should normally select only 2–3 E5 stories. Other work may remain enabling infrastructure, supporting evidence, architectural context, rejected alternatives, or interview backup material.

## Current evidence map

| Candidate | Core concept | Problem/risk | Current evidence | Maturity | Next gate | Decision |
| --- | --- | --- | --- | --- | --- | --- |
| Concurrent reviewer claim | Spring transaction, JPA @Version, optimistic locking, PostgreSQL | Two reviewers can claim one SUBMITTED application concurrently | ReviewerClaimOptimisticLockIntegrationTest proves exactly one winner and consistent reviewer/history/audit state | E2 | If useful in M8/M10, run controlled N-way claims and retain winner/conflict/partial-side-effect counts | Primary candidate — high |
| Concurrent application update | Transaction, optimistic locking | Concurrent writers can overwrite changes or leave partial audit rows | OptimisticLockIntegrationTest proves one commit/one conflict and no loser audit | E2 | Optional scaled contention evidence | Supporting evidence |
| Attachment DB/object consistency and Garage endpoint availability | PostgreSQL, Garage, SHA-256, reconciliation, app-local endpoint failover | Garage replication preserved object copies but a fixed client endpoint still broke attachment availability and left explicit FAILED metadata | M3 lifecycle tests plus M10 R3a/R3b comparison; R3b fixed-endpoint loss produced 28.6920% attachment errors and 64 FAILED rows, then ADR-005 same-fault retest produced 0% attachment/non-attachment errors and zero new lifecycle residue | E5 | Final primary reliability story; preserve single-node/app-01/FAILED-row limits | **FINAL PRIMARY** |
| Applicant edit stale-load race | React async effect, Playwright trace | Stale duplicate load could overwrite in-progress user input | M5 final E2E exposed it; trace identified ordering; cancellation + focused regression test fixed it | E2 | No forced expansion | Supporting debugging story |
| Immutable release + rollback | OCI artifact, manifest/checksum, versioned release, CI/CD | M4 built from a working tree/local JAR and M5 frontend had no durable paired release identity, so exact redeploy/rollback was not proven | M6 retained exact-SHA/digest handoff, paired backend/frontend activation, Flyway V5 verification, full HTTPS/API/Garage smoke, a real schema-compatible B→A rollback observed at 38.346 s with no DB down-migration, post-rollback revalidation, return to the intended release, final Phase 6 manual/runtime validation, and two clean OpenTofu no-drift plans | E5 | Strong supporting story for delivery/change-control questions; retained but not one of the three headline cases | Supporting story — high |
| PostgreSQL query bottleneck | pg_stat_statements, EXPLAIN ANALYZE BUFFERS, Flyway index design | M8 peak load exposed reviewer-queue read cost, DB CPU saturation, and datasource-pool waiting | M9 retained exact SQL/plans, rejected predicate simplification, added one `(status, updated_at, id) INCLUDE (reviewer_id)` index, then repeated equivalent W2/W3 conditions: W3 non-file p95 2,067.479→80.909 ms, reviewer result/count means 417.049/305.405→0.645/9.497 ms, db CPU avg 90.94%→37.113%, Hikari pending avg 39.52→1.256, completed business requests 29,814→44,097 | E5 | Final primary story; preserve the transport-error caveat and residual count cost | **FINAL PRIMARY** |
| Attachment reconciliation cost | JPA/SQL, Garage I/O, hashing | Reconciliation scans status groups and reads/hashes objects; scale cost is unknown | Code path exists; no representative measurement | E0 | Observe in M8/M9; optimize only if material | Candidate only |
| Observability stack | Metrics/logs/traces, Grafana, alert delivery, failure isolation | Later claims need trustworthy evidence and observability must not become a business-path dependency | M7 live verification proved required metrics/logs/traces, four dashboards over real telemetry, Prometheus → Alertmanager firing/clear, full business smoke during central observability outage, telemetry recovery, and final runtime no-drift | E2 | Use this substrate in M8–M10 and retain measurement/failure evidence; do not promote installation alone into a primary story | Enabling infrastructure, not primary story |
| Redis/cache | Cache/TTL/invalidation | No measured problem currently justifies cache | Explicitly excluded by current guardrails | E0 / rejected for now | Reconsider only after measured DB/query/code analysis proves need and stale-data policy is defined | Do not add for résumé value |
| JPA N+1 | Fetch strategy | No confirmed N+1 bottleneck is recorded; targeted EntityGraph/join-fetch paths already exist | No measured problem | E0 | Fix only if profiling finds a real query explosion | Do not manufacture tutorial story |
| Backup/recovery correctness | PostgreSQL PITR, cross-store checkpoint, IaC recovery, business/attachment invariants | Process restart alone cannot prove that PostgreSQL and attachment data are recoverable as a coherent business system | M11 restored PostgreSQL to a separate PITR VM with PRE included/POST excluded, measured DB PITR RTO 27.229 s and marker recovery gap ≤1.087882 s; then restored the verified DB/object checkpoint into a separate Tokyo DR topology, passed HTTPS applicant/reviewer smoke and repository-owned history/audit/attachment SHA-256 integrity checks, removed temporary recovery infrastructure, and returned the Seoul runtime to no-drift | E5 | Final primary recovery story; preserve the unmeasured full-DR RTO/effective-RPO limitation | **FINAL PRIMARY** |

## Final M12 primary selection

M12 Phase 1 selected exactly three headline stories:

1. **M9 PostgreSQL query bottleneck** — performance/database diagnosis;
2. **M10 Garage endpoint failover** — reliability/fault isolation;
3. **M11 disaster recovery correctness** — backup/recovery/business continuity.

M6 immutable release/rollback remains the strongest supporting story, especially for
CI/CD/change-control questions.

Selection rationale is retained in:

`docs/portfolio/M12_STORY_SELECTION.md`

## Evidence-card requirement

Any candidate promoted beyond E2 must get a committed evidence card based on docs/portfolio/EVIDENCE_CARD_TEMPLATE.md.

The card must contain:

1. Context / assumption — why the scenario is plausible.
2. Problem — what was actually observed; separate observation from hypothesis.
3. Baseline — dataset, workload, environment, release SHA, and measured values or correctness outcome.
4. Analysis — evidence used to narrow the cause.
5. Options considered — meaningful alternatives and why rejected/accepted.
6. Decision / action — smallest implemented change.
7. Verification — same or equivalent condition re-tested.
8. Trade-off / limit — what remains unsolved and what complexity was added.
9. Repository evidence — code/test/migration/CI/runtime references.
10. Claim wording — one factual résumé/interview sentence.

## Scenario board for M8–M10

These are hypotheses to test, not pre-approved problems.

### Deadline submission burst
Assume applicants cluster save/upload/submit near closing time. Observe save/submit latency and errors, DB/thread pressure, attachment path, and conflicts. Do not add a queue/cache merely because a burst was assumed.

### Review opening / reviewer contention
Assume multiple reviewers consume a newly opened queue concurrently. Observe queue latency, claim conflict rate, duplicate assignment count, ordering, and audit/history integrity.

### Attachment growth / reconciliation
Assume application count multiplied by several files increases metadata/object-store work. Observe reconciliation duration, object-store reads/lists, hash work, query behavior, and repair counts.

### Operational read growth
Assume accumulated applications/history/audit are paged and filtered by reviewer/admin users. Observe plans, scanned rows/buffers, sort/join work, and page latency.

Only scenarios that expose meaningful behavior should survive into M9/M10.

## Milestone evidence roles

### M6 — Operations & Delivery
Primary candidate: exact release identity and rollback. GHCR, WIF, Ansible, and symlinks are mechanisms, not separate résumé claims. A strong result proves exact artifact identity, paired frontend/backend release, real rollback, post-rollback business smoke, and database-migration rollback limits.

### M7 — Observability
Primarily evidence infrastructure. Installing Prometheus/Grafana/Loki/Tempo is not an E5 claim. M7 is useful only when later workload/failure questions become measurable.

### M8 — Workload
Creates representative conditions and baselines, not optimizations. Record plausible assumptions, repeatable seeds/scenarios, latency/error/query/throughput/conflict measurements, and hypotheses that did not become problems. “No meaningful bottleneck observed” is valid.

### M9 — Performance
Promote measured bottlenecks only. At least one database path must follow:
workload → observation → SQL → EXPLAIN (ANALYZE, BUFFERS) → hypothesis → change → same-condition remeasurement.
Do not begin with a chosen solution such as Redis, N+1, or a speculative index.

### M10 — Reliability
Inject faults against explicit hypotheses. Retain expected vs observed behavior, business-state impact, detection evidence, recovery/reconciliation action, elapsed recovery/unresolved state, design change if any, and re-test.

### M11 — DR
Validate business correctness after restore, not only process startup. Retain backup point, failure point, target, recovery timing, accepted/unaccepted loss, and post-restore workflow/integrity checks.

### M12 — Portfolio
Invent no new technical depth. Select the strongest 2–3 E5 cards and compress them into résumé/interview form.

## Technology-introduction gate

Before adding a new major technology not already required by the frozen architecture, answer:

1. What measured or implemented requirement is not adequately handled now?
2. What evidence shows it is material?
3. What simpler change was considered first?
4. What new failure/operational complexity does the technology add?
5. How will the same condition be re-tested afterward?

If these cannot be answered, do not add the technology. This blocks résumé-driven additions such as Redis, Kafka, Elasticsearch, Kubernetes, or a second datastore without evidence.
