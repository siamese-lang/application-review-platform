# Application Review Platform — Portfolio Narrative

Status: FINAL SYSTEM NARRATIVE  
Project type: Personal, production-like system project  
Data boundary: Synthetic users, organizations, applications, files, and workloads only

## 1. Project in one paragraph

Application Review Platform is a support-program application and review system built to prove
more than CRUD behavior.

Applicants can discover programs, register, prepare applications, attach evidence, submit and
revise them, and track results. Reviewers claim submitted work and request revision, approve, or
reject. Administrators publish programs and inspect operational state.

The project then verifies that workflow across the boundaries that usually determine whether a
system can actually be operated: authorization, transactions, attachment integrity, exact
release identity, observability, representative load, measured SQL behavior, bounded fault
injection, backup, and recovery.

The project is intentionally described as **production-like**, not production-operated. All
identities and workloads are synthetic, and every quantitative claim below is tied to retained
repository/runtime evidence.

## 2. What the system is designed to protect

The core business state is not only an application row.

A valid application workflow includes:

- applicant ownership and role authorization;
- current application state;
- status history;
- reviewer assignment;
- audit records;
- attachment metadata;
- attachment object bytes;
- exact release identity when code is deployed or recovered.

The project therefore treats these as linked correctness boundaries rather than independent
features.

Core state flow:

```text
DRAFT
  ↓
SUBMITTED
  ↓
IN_REVIEW
  ├── NEEDS_REVISION ──→ SUBMITTED
  ├── APPROVED
  └── REJECTED
```

Representative user flow:

```text
public program discovery
→ applicant registration/login
→ draft/edit
→ attachment upload
→ submit
→ reviewer claim/start
→ revision or approve/reject
→ applicant status/history/result
```

## 3. Final architecture

The final persistent service runtime is intentionally simple at the application boundary and
separated at the operational boundary.

```text
Internet
  │ HTTPS
  ▼
edge-01: Nginx
  ├─ /, /assets/** → versioned React/Vite static release
  └─ /api/v1/**    → app-01: Spring Boot REST API
                          │
                          ├─ JDBC → db-01: PostgreSQL
                          │
                          └─ S3 → 127.0.0.1:3910
                                   app-local Nginx Garage proxy
                                      ├─ storage-01
                                      ├─ storage-02
                                      └─ storage-03

edge/app/db/storage telemetry
  └─→ obs-01: Prometheus / Loki / Tempo / Grafana / Alertmanager

ops-01
  └─→ OpenTofu / Ansible / release / recovery tooling
```

Persistent service/runtime nodes remain in Seoul. Temporary workload, backup, PITR, and
full-DR resources were created in Tokyo when required by the experiment and removed after
evidence was retained.

### Why this is not microservices

The domain does not need distributed service boundaries to demonstrate its business rules.
The application remains a modular monolith so transaction boundaries, authorization, state
transitions, and audit/history consistency can be reasoned about directly.

Operational roles are separated because edge, application, database, object storage,
observability, and operations have different failure and access boundaries. This creates useful
failure isolation without inventing application-level distributed complexity.

### Why GCP IaaS rather than managed application services

The project goal includes operating-system, network, reverse-proxy, database, object-storage,
deployment, telemetry, failure, and recovery behavior.

Compute Engine, Persistent Disk, VPC, firewall, IAP, and Cloud NAT preserve those boundaries.
Managed services such as GKE, Cloud SQL, managed Redis, or another object store were not added
merely to expand the technology list.

## 4. Security and data-integrity boundaries

### Browser and authentication

The React SPA and versioned REST API share one HTTPS origin through Nginx.

Authentication uses Spring Security sessions backed by Spring Session JDBC. Browser mutations
use CSRF protection. Public registration can create only APPLICANT identities; REVIEWER and
ADMIN identities are provisioned through controlled operations/bootstrap paths.

The project does not claim external identity proofing, email verification, MFA, password-reset
delivery, or enterprise SSO.

### Authorization and business rules

Role, ownership, program-intake, and application-state rules are enforced server-side in the
service/domain boundary. UI visibility is not treated as authorization.

Reviewer claim and application update paths use optimistic locking where concurrent writers must
not silently overwrite each other.

### Relational integrity

PostgreSQL schema evolution is Flyway-only.

Business state transitions, history, and audit effects are kept within explicit transactional
boundaries. Relational PK/FK/UNIQUE/NOT NULL/CHECK constraints and optimistic-lock versions are
used as part of the integrity model rather than leaving correctness to application convention
alone.

### Attachment integrity

PostgreSQL stores attachment metadata and Garage stores object bytes.

Attachment lifecycle state is explicit. Upload/download verification uses SHA-256, and
reconciliation paths exist for metadata/object consistency. The project distinguishes object
replication from independent backup and from application endpoint availability.

## 5. Delivery and observability as evidence infrastructure

The portfolio headline is not “used CI/CD and Grafana.” These components exist so later claims
can be verified.

### Exact release identity and rollback

A reviewed source SHA produces a release bundle containing paired backend/frontend payload
identity and checksums. The release is retained by immutable OCI digest and installed into
versioned runtime paths.

A real schema-compatible B → A rollback was executed in **38.346 seconds**, followed by the full
HTTPS/application/attachment smoke, then the intended release was reactivated and verified
again.

This is retained as a supporting delivery/change-control story rather than one of the three
headline cases.

### Observability

Prometheus, Loki, Tempo, Grafana, Alertmanager, and Alloy provide metrics, logs, traces, and
alerting for the later workload and failure experiments.

The observability stack was also isolated from the business path: central observability failure
did not become an application-availability dependency.

## 6. Primary case 1 — Diagnose a PostgreSQL bottleneck before changing the system

### Observed problem

A deterministic dataset of **100,000 applications** and a bounded mixed workload were used to
exercise the deployed HTTPS/session/CSRF path.

Under the retained W3 peak condition:

- offered load: 100 business requests/s;
- hard ceiling: 100 VUs;
- non-file p95: **2,067.479 ms**;
- completed business requests: **29,814**;
- db-01 CPU average: about **90.94%**;
- Hikari pending average: about **39.52**;
- reviewer result/count query means: **417.049 / 305.405 ms**.

The edge remained lightly utilized and the private application probe stayed healthy, so the
problem was not recorded as a general edge or process outage.

### How the cause was narrowed

The investigation used:

- workload results;
- Prometheus telemetry;
- `pg_stat_statements`;
- exact application SQL;
- `EXPLAIN (ANALYZE, BUFFERS)`.

The reviewer queue path showed parallel sequential scans, large application-table buffer work,
and explicit sorting.

A predicate-only simplification was measured first and rejected because the scan/buffer problem
remained. Increasing the datasource pool, resizing the VM, or adding a cache would have changed
capacity or complexity without addressing the measured access path.

### Decision

Add one Flyway-managed index:

```text
applications(status, updated_at, id) INCLUDE (reviewer_id)
```

No pool-size, VM-size, PostgreSQL-setting, cache, or reviewer-query architecture change was
bundled with the intervention.

### Same-condition verification

Under equivalent retained W3 conditions:

| Signal | Before | After |
| --- | ---: | ---: |
| non-file p95 | 2,067.479 ms | 80.909 ms |
| reviewer result mean | 417.049 ms | 0.645 ms |
| reviewer count mean | 305.405 ms | 9.497 ms |
| db CPU average | 90.94% | 37.113% |
| Hikari pending average | 39.52 | 1.256 |
| completed business requests | 29,814 | 44,097 |

The project regression criterion changed from FAIL to PASS.

### What this proves

The useful result is not “added an index.” It is the evidence chain:

`representative load → telemetry → SQL → execution plan → rejected alternative → bounded change → same-load remeasurement`

### Limit

The count query still processes the full matching set. The after-run also retained rare
client/transport outliers whose exact root cause was not proven. They are documented rather
than silently excluded.

The workload is a bounded synthetic experiment, not a production-capacity claim, and the
internal latency threshold is not an SLA.

Evidence:

- `docs/portfolio/M8_POSTGRESQL_QUERY_BOTTLENECK_EVIDENCE.md`
- `docs/operations/M8_WORKLOAD_EVIDENCE.md`
- M9 performance evidence referenced by the evidence card

## 7. Primary case 2 — Replication existed, but the application still had a single endpoint failure

### Observed problem

Garage stored attachment bytes across three nodes with replication factor 3, but the Spring
application originally used one fixed S3 endpoint: storage-01.

A controlled comparison made the failure boundary visible.

When storage-02 was stopped:

- attachment error rate: **0%**.

When the configured endpoint storage-01 was stopped:

- overall attachment error rate: **28.6920%**;
- existing-object read errors: **27.8481%**;
- upload errors: **27.0042%**;
- persistent FAILED attachment metadata rows created during the outage: **64**.

At the same time, PostgreSQL, the application process, non-attachment requests, and the two
remaining Garage nodes stayed healthy.

### Analysis

The comparison separated two concepts that are easy to conflate:

- **object replication** — copies still existed on peer Garage nodes;
- **client endpoint availability** — the application could not reach those healthy copies
  because its only configured endpoint was down.

The measured problem therefore did not justify PostgreSQL HA, another storage product, or a
large load-balancing redesign.

### Decision

Add one app-local Nginx S3 proxy on `127.0.0.1:3910`.

The Spring application connects to the loopback endpoint. Nginx can proxy to all three Garage
S3 nodes while preserving the request properties required for S3 signing.

This was selected because app-01 was already an application failure domain; the local proxy did
not create a new independent business-path dependency.

### Same-fault verification

The exact storage-01 Garage-container fault was repeated.

Retest results:

- 240 attachment attempts;
- existing-read error rate: **0%**;
- upload error rate: **0%**;
- download-after-upload error rate: **0%**;
- delete error rate: **0%**;
- 480 non-attachment attempts, error rate: **0%**;
- new FAILED/PENDING/DELETE_PENDING lifecycle residue: **0/0/0**.

The full HTTPS business/attachment smoke then passed.

### What this proves

The useful result is not “put Nginx in front of Garage.” It is the distinction between
redundant data and a redundant client path, followed by a same-fault re-test of the minimum
change.

### Limit

The experiment proves one bounded single-Garage-node failure. app-01 remains a single
application failure domain. Multi-node loss, network partitions, continuous multi-region
availability, and PostgreSQL HA are outside the claim.

The earlier 64 FAILED rows were removed by guarded synthetic-dataset reset before the retest;
the project does not claim automatic reconciliation of those rows.

Evidence:

- `docs/portfolio/M10_GARAGE_ENDPOINT_FAILOVER_EVIDENCE.md`
- `docs/operations/M10_RELIABILITY_EVIDENCE.md`
- `docs/architecture/ADR-005-garage-endpoint-failover.md`

## 8. Primary case 3 — Prove recoverability of business state, not only process startup

### Recovery question

The system stores workflow state in PostgreSQL and attachment bytes in Garage.

Restarting services, or verifying Garage replication, cannot prove that a requested database
point can be restored or that database metadata and object bytes can be recovered coherently.

M11 therefore separated the problem into:

1. independent PostgreSQL point-in-time recovery;
2. a verified PostgreSQL/Garage consistency checkpoint;
3. a rebuild into separate recovery infrastructure;
4. application-level business and attachment verification.

### Independent PostgreSQL PITR

A synthetic marker created explicit states before and after the requested recovery target.

Target:

`2026-09-16T10:44:13.321143+00`

The recovered database:

- contained PRE;
- excluded POST;
- had orphan applications: 0;
- had application/latest-history status mismatch: 0;
- had terminal applications missing terminal history: 0.

Measured DB PITR:

- RTO to business/data verification: **27.229 seconds**;
- marker-granularity recovery gap: **≤ 1.087882 seconds** before the target.

These met the project’s frozen internal DB targets of RTO ≤30 minutes and RPO ≤5 minutes.

### Cross-store checkpoint

PostgreSQL and Garage do not share a distributed transaction or storage snapshot.

Instead of pretending they were atomic, the project explicitly bounded the consistency window:

`block public mutations → drain → stop application/background reconciliation → verify attachment lifecycle → back up PostgreSQL → copy/manifest Garage objects → verify → restart → reopen writes`

Checkpoint:

`m11-checkpoint-20260916T121255Z`

At the checkpoint:

- AVAILABLE: 17;
- PENDING: 0;
- DELETE_PENDING: 0;
- FAILED: 0;
- Garage backup manifest: 21 objects with retained size/SHA-256 identity.

Measured maintenance window:

- frozen start → verified backup set: **76.718 seconds**;
- frozen start → writes resumed: **98.711 seconds**.

These are checkpoint-maintenance measurements, not full-DR RTO.

### Separate full-system rebuild

Fresh Tokyo recovery VMs and disks were used rather than reusing retained Seoul service data.

The rebuild verified:

- exact checkpoint PostgreSQL restore;
- 21 checkpoint objects restored and key/size/SHA-256 verified;
- checkpoint-compatible exact release activation;
- normal TLS HTTPS path;
- applicant registration/session/CSRF;
- application create/edit/submit;
- attachment SHA-256 integrity;
- reviewer start/approve;
- final APPROVED state/history;
- reviewer/state/history/audit/attachment integrity mismatches: 0.

Final result:

`M11_FULL_DR_INTEGRITY=PASS`

Temporary recovery resources were then removed, the retained Seoul runtime was restored, a
stale pgBackRest archive configuration exposed during teardown was corrected through a
repository-owned cleanup, and the final persistent OpenTofu plan reported no drift.

### What this proves

The recovery claim is based on actual restored business state and attachment integrity, not on
a process becoming healthy.

### Limit

No authoritative single full-DR start timestamp and business-ready completion timestamp were
retained. Therefore the project **does not claim an end-to-end full-DR RTO**.

It also does not claim an effective full-system RPO against one simulated disaster timestamp.

PostgreSQL remains a single primary, automatic failover is not implemented, and continuous
multi-region availability is outside scope.

Evidence:

- `docs/portfolio/M11_DISASTER_RECOVERY_EVIDENCE.md`
- `docs/operations/M11_PHASE2_PITR_EVIDENCE.md`
- `docs/operations/M11_PHASE3_CHECKPOINT_EVIDENCE.md`
- `docs/operations/M11_PHASE4_FULL_DR_EVIDENCE.md`
- `docs/operations/M11_PHASE6_CLOSEOUT_EVIDENCE.md`

## 9. Evidence model

The project uses the repository as the durable source of truth.

A portfolio claim is allowed only when it has one or more of:

- committed implementation/configuration;
- focused integration/concurrency/E2E tests;
- exact-head CI;
- sanitized runtime output;
- retained workload measurements;
- SQL/query plans;
- bounded fault experiments;
- restore/recovery records.

The preferred problem-solving chain is:

`context → observed problem → baseline → analysis → alternatives → decision → action → verification → trade-off`

This is also why some implemented components do not become headline stories. Observability,
OpenTofu, Ansible, CI/CD, and the UI are important enabling layers, but technology presence by
itself is not treated as a portfolio result.

## 10. What was deliberately not added

The project rejected additional complexity when the evidence did not justify it.

Examples:

- Redis/cache was not added because no measured residual database problem required it.
- Kubernetes was not added because the VM-based architecture could test the intended
  operational boundaries directly.
- Microservices were not introduced because the domain did not require distributed
  transactions/service ownership.
- PostgreSQL HA was not added to disguise the documented single-primary limitation.
- A second object-storage product or managed load balancer was not added to solve the measured
  Garage endpoint problem.
- A new backup product was not introduced after pgBackRest/Garage backup recovery was verified.

These omissions are part of the design discipline: solve the measured problem at the smallest
appropriate boundary.

## 11. Technology summary

Technology is listed here only after the problem/evidence narrative.

| Boundary | Technology |
| --- | --- |
| Browser | React, TypeScript, Vite |
| Edge | Nginx, HTTPS |
| Application | Java 21, Spring Boot, Spring Security, Spring Session JDBC, Spring Data JPA |
| Database | PostgreSQL, Flyway, pg_stat_statements |
| Object storage | Garage S3 API |
| Observability | Prometheus, Loki, Tempo, Grafana, Alertmanager, Alloy |
| Workload | k6 |
| Backup/recovery | pgBackRest, independent Garage object manifests |
| Infrastructure | GCP Compute Engine/VPC/Persistent Disk, OpenTofu, Ansible |
| Delivery | GitHub Actions, GHCR, exact-SHA release bundles |
| Secret handling | SOPS + age |

## 12. Claim boundary

This portfolio does not claim:

- real production users or traffic;
- contractual SLA/SLO;
- enterprise identity verification;
- PostgreSQL automatic failover/HA;
- continuous multi-region availability;
- tested simultaneous multi-node/region failures beyond the retained scenarios;
- full-DR end-to-end RTO or effective full-system RPO;
- production capacity inferred from the bounded synthetic workloads.

It does claim what was actually retained:

- recognizable support-program application/review workflows;
- server-side authorization/state/integrity boundaries;
- exact release and rollback evidence;
- representative load and direct SQL-plan diagnosis;
- fault isolation and same-fault correction verification;
- independent PITR and full recovery correctness of business/attachment state.

## 13. Repository evidence entry points

Start here:

- final story selection:
  `docs/portfolio/M12_STORY_SELECTION.md`;
- M9 performance case:
  `docs/portfolio/M8_POSTGRESQL_QUERY_BOTTLENECK_EVIDENCE.md`;
- M10 reliability case:
  `docs/portfolio/M10_GARAGE_ENDPOINT_FAILOVER_EVIDENCE.md`;
- M11 recovery case:
  `docs/portfolio/M11_DISASTER_RECOVERY_EVIDENCE.md`;
- M6 supporting release/rollback case:
  `docs/portfolio/M6_IMMUTABLE_RELEASE_ROLLBACK_EVIDENCE.md`;
- complete evidence map:
  `docs/portfolio/PORTFOLIO_EVIDENCE_MAP.md`.

## 14. Summary

The strongest result of the project is not the number of infrastructure components.

It is the repeated operating pattern:

1. implement a recognizable business workflow with explicit integrity boundaries;
2. create evidence that exposes actual behavior;
3. change only the boundary supported by that evidence;
4. repeat the relevant condition;
5. retain the result and its limitation.

The three headline cases demonstrate that pattern across database performance, runtime
reliability, and disaster recovery.
