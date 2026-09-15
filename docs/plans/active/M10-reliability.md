# M10 Reliability — Execution Plan

Status: ACTIVE

## Goal

Verify how the deployed Application Review Platform behaves under bounded, intentional
service failures, and retain evidence of blast radius, detection, business-state impact,
recovery, and any justified corrective change.

M10 is successful when it can answer, with retained runtime evidence:

> When a required runtime component fails, what actually breaks, what remains available,
> how is the failure detected, how is service restored, and is business state still
> consistent afterward?

M10 is not a high-availability redesign. A negative result or an explicitly documented
single point of failure is valid evidence.

The preferred evidence chain is:

`explicit hypothesis → healthy baseline → bounded fault → observed blast radius →
detection evidence → recovery action/time → business-state verification → same-fault re-test
only if a change is implemented`

## Planning base and entry state

Planning base:

`12871fc19d7f2abd39d864dc297d969344b443a9`

M1–M9 are complete.

M9 revalidated application release:

`d90eb558bdb6317d49b0a7ce82148ddeb4b5babf`

Persistent Seoul runtime:

- edge-01: `10.40.0.10`;
- app-01: `10.40.0.20`;
- db-01: `10.40.0.30`;
- storage-01: `10.40.0.41`;
- storage-02: `10.40.0.42`;
- storage-03: `10.40.0.43`;
- ops-01: `10.40.0.50`;
- obs-01: `10.40.0.60`.

Retained runtime overrides:

- storage-03 machine: `e2-small`;
- storage-03 boot disk: `pd-standard`.

M9 closeout removed the temporary Tokyo load generator and its dedicated subnet/router/NAT.
The final `enable_loadgen=false` OpenTofu plan reported no changes.

Relevant retained evidence:

- `docs/operations/M7_OBSERVABILITY_EVIDENCE.md`;
- `docs/operations/M8_WORKLOAD_EVIDENCE.md`;
- `docs/operations/M9_PERFORMANCE_EVIDENCE.md`;
- `docs/portfolio/PORTFOLIO_EVIDENCE_MAP.md`.

## Fixed reliability-scenario disposition

The frozen workload baseline defines R1–R5.

### R1 — application process failure

M10 executes this scenario.

Current relevant design:

- app-01 runs `arp.service`;
- systemd uses `Restart=on-failure`;
- application sessions are stored in PostgreSQL through Spring Session JDBC;
- Nginx remains a separate failure domain on edge-01.

Primary hypothesis:

A process crash should cause a bounded API interruption, systemd should restart the backend
without operator deployment, and previously persisted session/business state should remain
usable after the process returns.

Do not use `systemctl stop` as the initial crash experiment because an intentional stop does
not exercise `Restart=on-failure`. Verify the exact live service/unit first, then inject a
process failure that systemd classifies as a failure.

### R2 — PostgreSQL failure during normal workload

M10 executes this scenario.

Current relevant design:

- PostgreSQL is the single structured system of record;
- there is one PostgreSQL primary;
- no database failover architecture is claimed;
- `ARPPostgreSQLUnavailable` fires only after `pg_up == 0` for five minutes.

Primary hypothesis:

A primary-database outage should make DB-dependent API/session operations unavailable while
the static edge remains up. After PostgreSQL is restored, the existing application process
and Hikari pool should recover without a redeploy, and committed business state should remain
consistent.

This scenario is expected to demonstrate a known single point of failure, not transparent HA.

### R3 — Garage node failure in the three-node cluster

M10 executes this scenario.

Current relevant design:

- Garage replication factor is 3;
- storage nodes are placed across three Seoul zones;
- the application S3 endpoint is currently fixed to storage-01;
- PostgreSQL stores attachment metadata while Garage stores attachment bytes.

R3 is split into two bounded subcases because they test different mechanisms:

1. **R3a non-endpoint node loss** — stop the Garage service/container on storage-02 or
   storage-03 while storage-01 remains the client endpoint.
   - Hypothesis: replication/quorum should preserve attachment availability if the cluster
     tolerates one replica-node loss.
2. **R3b endpoint node loss** — stop the Garage service/container on storage-01 while the
   other two nodes remain healthy.
   - Hypothesis: object replicas may remain healthy but the application may still lose
     attachment access because its configured endpoint is a single node.

If R3b exposes endpoint availability as a single point of failure, retain that as evidence.
Do not automatically add a load balancer, failover endpoint, new proxy, or managed object
service. Any architecture-level fix requires an ADR and a separate evidence-supported
decision.

### R4 — bad deployment and rollback

Do not rerun this as new M10 work.

M6 already retained an exact-release rollback drill, paired frontend/backend release identity,
schema-compatible rollback, post-rollback smoke, and measured rollback time. That evidence is
already E5.

M10 may reference M6 as the completed R4 evidence.

### R5 — logical DB corruption followed by PITR

Do not execute this in M10.

R5 belongs to M11 DR because the frozen backup/recovery baseline requires pgBackRest/PITR,
RPO/RTO measurement, and post-restore business correctness.

## Reliability evidence standard

Every executed M10 fault scenario must retain all applicable items below.

### 1. Hypothesis and expected blast radius

Before injecting the fault, record:

- exact component and failure mechanism;
- expected unavailable and expected unaffected paths;
- expected detection signal;
- expected automatic vs manual recovery behavior;
- business-state invariants that must survive.

Do not rewrite the hypothesis after seeing the result.

### 2. Exact identity

Record:

- source SHA;
- deployed backend/frontend release SHA;
- dataset/fixture identity;
- runtime node identities;
- faulted node/service;
- exact start, fault, restore, and verification timestamps.

### 3. Client/business observation

Use synthetic traffic through the real HTTPS/session/CSRF boundary.

Retain:

- attempted and successful business requests;
- HTTP/network errors;
- request families affected;
- first observed failure;
- first successful request after recovery;
- session continuity where relevant.

### 4. Server/telemetry observation

Use existing M7 observability before adding new telemetry.

Retain relevant:

- blackbox application probe;
- PostgreSQL `pg_up`;
- Hikari active/pending;
- node CPU/memory;
- Nginx access/error logs;
- Spring logs;
- PostgreSQL logs;
- Garage metrics/logs;
- systemd/container state.

Existing five-minute alert delays are part of the system behavior. Do not hold a fault merely
to make an alert fire unless detection latency is an explicit scenario objective.

### 5. Business-state verification

A restarted process is not proof of recovery.

After every scenario, verify the applicable invariants:

- application state matches its latest status-history transition;
- reviewer ownership/state is not duplicated or silently overwritten;
- audit/history rows contain no partial loser-side effects;
- DB referential constraints remain satisfied;
- `AVAILABLE` attachment metadata still maps to an object with matching size/SHA-256;
- stale `PENDING`, `FAILED`, or `DELETE_PENDING` attachment states are counted explicitly;
- orphan Garage objects are observed before any reconciliation cleanup;
- a full representative HTTPS business flow succeeds after recovery.

If reconciliation is required, capture the pre-reconciliation inconsistency first, then the
reconciliation report/result, then re-run the invariants.

### 6. Recovery measurement

Measure recovery from the fault event to a clearly defined recovered state.

Examples:

- R1: process failure → first healthy representative API/business request;
- R2: database restore/start → application/session/business path healthy without redeploy;
- R3: Garage node restore → attachment read/write integrity and cluster state healthy.

Do not call a service recovered merely because the process is `active`.

## Workload and fault-driver model

M10 should reuse the M8 workload semantics rather than invent a new business mix.

For scenarios that need sustained normal traffic:

- use dataset M / seed `20260914`;
- use the deterministic interactive overlay;
- preserve the W2 business mix:
  40/15/10/20/10/5 for
  list-detail/create-save/submit-resubmit/reviewer-queue-detail/review-action/attachment;
- use the real HTTPS/session/CSRF boundary;
- use a normal-load profile, not the W3 saturation profile.

M10 is a failure experiment, not another capacity benchmark. Do not inject faults while the
database is intentionally saturated.

The repository-defined temporary cross-region `loadgen-01` may be recreated only after a
reviewed OpenTofu plan if the scenario harness needs sustained concurrent traffic. Reuse the
existing Tokyo/e2-standard-2 topology rather than designing another load generator.

If recreated:

- record that the resource is temporary M10 test infrastructure;
- verify the create plan before apply;
- destroy it at M10 closeout unless a reviewed M11 plan explicitly requires it.

The M10 harness may derive from W2 but may use scenario-specific baseline/fault/recovery
phases. Do not label such runs as W2 unless they actually preserve the W2 runner and timing.

## Fault-injection guardrails

- Use synthetic data only.
- Execute one fault scenario at a time.
- Return the runtime to a verified healthy state before the next scenario.
- Prefer service/process/container failure over VM/disk destruction for the first experiment;
  isolate the intended failure mechanism.
- Never detach/delete persistent disks or corrupt live data merely to create a dramatic fault.
- Do not run PITR/logical corruption in M10.
- Never inject multiple independent faults in one retained run.
- Never print or commit credentials.
- Preserve unexpected partial states before repair.
- If a fault command or target unit/container is not confirmed from the live node, inspect it
  first rather than guessing.
- Keep the persistent Seoul topology and M0 architecture frozen unless evidence requires an
  ADR.

## Implementation phases

### Phase 1 — reliability harness and healthy-control verification

Status: ACTIVE

Goal: create the minimum repeatable tooling needed to execute R1–R3 without ad-hoc manual
timing or unretained evidence.

Expected work:

1. create a small repository-owned M10 reliability runner/controller;
2. reuse existing W2 business semantics and Dataset M tooling;
3. emit an immutable run manifest with source/release/dataset/fault identity;
4. retain k6/client results and scenario timestamps;
5. capture selected Prometheus/log/runtime observations for the exact scenario window;
6. provide post-fault business/integrity checks;
7. if sustained workload requires it, recreate the existing temporary Tokyo loadgen through
   a reviewed OpenTofu plan;
8. run one healthy control with no fault before retaining any failure result.

Do not build a general chaos-engineering framework.

Done condition:

- healthy control passes;
- harness records enough evidence to distinguish client, edge, app, DB, and Garage effects;
- no fault has yet been injected.

### Phase 2 — R1 application process failure

Status: PLANNED

Execute one bounded backend process crash.

Required observations:

- exact failure injection and systemd restart behavior;
- API/client interruption duration and status/error shape;
- blackbox/application telemetry;
- session continuity after restart;
- no DB/Garage fault is introduced;
- post-recovery business smoke and state invariants.

Decision after observation:

- if the existing restart policy works and state is consistent, retain the positive result;
- if restart/session/recovery behavior fails, identify the smallest causal fix and rerun R1;
- do not add redundant application replicas solely to make R1 look more sophisticated.

### Phase 3 — R2 PostgreSQL outage during normal workload

Status: PLANNED

Execute one bounded outage of the actual live PostgreSQL cluster/service while normal M10
traffic is active.

Before injection, inspect the live PostgreSQL unit/cluster and choose the reversible service
command from actual state.

Required observations:

- edge/static availability vs DB-dependent API availability;
- session behavior;
- PostgreSQL `pg_up` and application probe behavior;
- Hikari pending/reconnection behavior;
- Nginx/Spring/PostgreSQL error shape;
- any in-flight mutation outcome;
- recovery without application redeploy if that is what occurs;
- post-recovery database/business invariants.

To test the existing five-minute PostgreSQL alert, a fault window longer than five minutes
may be used only if the healthy baseline and synthetic-data safeguards are confirmed first.
Record alert firing/clear timing if exercised.

A single-primary outage is expected to be a service outage. Do not classify that expected
architecture limit as a failed experiment.

### Phase 4 — R3 Garage single-node failure

Status: PLANNED

Run R3a first, restore health, then run R3b.

#### R3a — non-endpoint replica node

- stop Garage only on storage-02 or storage-03;
- keep its disk/VM intact;
- verify cluster state;
- exercise attachment upload/download/hash checks and non-attachment business flow;
- restore the node;
- verify cluster recovery and object integrity.

#### R3b — application endpoint node

- stop Garage only on storage-01;
- keep PostgreSQL, app, edge, and the other Garage nodes healthy;
- verify whether non-attachment workflow remains available;
- measure attachment failure/recovery behavior;
- inspect metadata/object partial states;
- restore storage-01;
- run reconciliation only after preserving pre-reconciliation evidence.

Decision after R3:

- if replication provides the expected node-loss behavior, retain it;
- if endpoint loss exposes a distinct availability gap, document it separately from object
  durability;
- do not conflate “replicas survived” with “application attachment endpoint remained
  reachable.”

### Phase 5 — residual reliability decision

Status: PLANNED

After R1–R3:

- rank observed problems by actual business impact and recovery evidence;
- choose at most one bounded corrective change if evidence clearly justifies it;
- rerun the same fault after that change;
- if the required fix changes database failover architecture, object-storage endpoint
  architecture, service boundaries, or another frozen architectural boundary, stop and
  propose an ADR instead of implementing it silently;
- if current behavior is acceptable with documented limitations, make no change.

Do not add reviewer N-way contention, extra multi-node faults, network partitions, disk
corruption, or resource exhaustion unless R1–R3 leave a concrete unresolved reliability
question. Existing reviewer-claim concurrency remains valid E2 evidence without forced
expansion.

### Phase 6 — M10 closeout

Status: PLANNED

Required closeout:

- sanitized `docs/operations/M10_RELIABILITY_EVIDENCE.md`;
- exact source/release/fault/run identities;
- expected vs observed blast radius for R1–R3;
- detection/recovery timing;
- business-state verification;
- repair/reconciliation evidence where applicable;
- explicit unresolved limitations;
- Evidence Map updates;
- an Evidence Card only when a candidate advances beyond E2;
- reference M6 as completed R4 evidence;
- explicitly hand R5/PITR to M11;
- final persistent-runtime drift check;
- explicit temporary loadgen lifecycle decision;
- active M10 plan moved to completed;
- exact-head CI and post-merge `main` CI successful.

## Expected repository areas

Likely M10 areas include:

- `docs/plans/active/M10-reliability.md`;
- `docs/operations/M10_RELIABILITY_EVIDENCE.md`;
- `scripts/reliability/` or another existing script area for bounded fault orchestration;
- `workload/k6/` only for the minimum M10 business/fault driver;
- existing Dataset M and W2 workload tooling;
- existing M7 Prometheus/Loki/Tempo/Grafana telemetry;
- existing `deploy/cloud-smoke.sh` where post-recovery smoke is reusable;
- focused application tests only if a measured fault exposes an application defect;
- `docs/portfolio/PORTFOLIO_EVIDENCE_MAP.md` and an evidence card only when warranted.

No Flyway migration, new service, queue, cache, load balancer, database replica, or new
observability product is planned in advance.

## Completion criteria

M10 is complete only when:

- R1 application process failure has retained failure/recovery/business-state evidence;
- R2 PostgreSQL outage under normal synthetic workload has retained blast-radius, detection,
  recovery, and state evidence;
- R3 Garage node failure has distinguished replica-node behavior from endpoint-node behavior;
- R4 is referenced to the already-completed M6 rollback evidence rather than rerun;
- R5/PITR remains deferred to M11;
- any implemented corrective change is re-tested with the same fault;
- unexpected partial states are retained before repair;
- no unjustified HA architecture or résumé-driven technology is introduced;
- temporary test infrastructure is explicitly cleaned up or handed off;
- final persistent runtime has no unexplained OpenTofu drift;
- final exact-head and post-merge `main` CI pass.
