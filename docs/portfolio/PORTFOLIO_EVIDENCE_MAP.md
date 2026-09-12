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
| Attachment DB/object consistency | PostgreSQL, Garage, SHA-256, reconciliation, REQUIRES_NEW | DB metadata and object storage cannot be one local transaction; partial states are possible | M3 Garage/failure tests, attachment state machine, reconciliation, optimistic-lock test | E2 | M10 fault experiments should retain resulting states, reconciliation result, repair time, unresolved errors | Primary candidate if failure evidence is strong |
| Applicant edit stale-load race | React async effect, Playwright trace | Stale duplicate load could overwrite in-progress user input | M5 final E2E exposed it; trace identified ordering; cancellation + focused regression test fixed it | E2 | No forced expansion | Supporting debugging story |
| Immutable release + rollback | OCI artifact, manifest/checksum, versioned release, CI/CD | M4 built from a working tree/local JAR and M5 frontend had no durable paired release identity, so exact redeploy/rollback was not proven | M6 Phase 1 now publishes one backend/frontend release manifest by full main SHA to GHCR, retains payload SHA-256 values, and proves pull-by-digest round-trip verification; final Phase 1 digest is recorded in the active M6 plan | E1 | Phase 2 must consume the retained artifact through versioned install/rollback mechanics; Phase 5 must prove a real schema-compatible rollback and post-rollback smoke before this becomes a primary story | Primary candidate — high if drill succeeds |
| PostgreSQL query bottleneck | pg_stat_statements, EXPLAIN ANALYZE BUFFERS, index/query design | Unknown until representative workload is measured | Candidate paths defined; no measured bottleneck yet | E0 | M8 creates baseline; M9 chooses only an actual bottleneck and repeats same-condition measurement after change | Mandatory search; outcome not predetermined |
| Attachment reconciliation cost | JPA/SQL, Garage I/O, hashing | Reconciliation scans status groups and reads/hashes objects; scale cost is unknown | Code path exists; no representative measurement | E0 | Observe in M8/M9; optimize only if material | Candidate only |
| Observability stack | Metrics/logs/traces | Later claims need trustworthy evidence | Planned M7 | E0 | Must make M8–M10 questions measurable | Enabling infrastructure, not primary story |
| Redis/cache | Cache/TTL/invalidation | No measured problem currently justifies cache | Explicitly excluded by current guardrails | E0 / rejected for now | Reconsider only after measured DB/query/code analysis proves need and stale-data policy is defined | Do not add for résumé value |
| JPA N+1 | Fetch strategy | No confirmed N+1 bottleneck is recorded; targeted EntityGraph/join-fetch paths already exist | No measured problem | E0 | Fix only if profiling finds a real query explosion | Do not manufacture tutorial story |
| Backup/recovery correctness | PostgreSQL recovery, business invariants | Process restart is not proof of recoverable business state | Planned M11 | E0 | Real restore/PITR evidence, post-restore business checks, measured recovery timing | Candidate if distinctive |

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
