# M7 Observability — Execution Plan

Status: ACTIVE

## Goal

Build the minimum trustworthy observability layer required to measure the existing
Application Review Platform before M8 workload generation, M9 performance analysis, and
M10 fault experiments.

M7 must make the current system observable across:

- host/runtime health;
- public edge behavior;
- Spring Boot application metrics and traces;
- PostgreSQL operational state;
- Garage cluster/storage state;
- centralized logs;
- alert delivery inside the private operations boundary.

M7 is primarily **evidence infrastructure**. Installing Prometheus, Loki, Tempo, Grafana,
Alertmanager, or Grafana Alloy is not by itself a portfolio problem-solving claim.

The milestone succeeds when later experiments can answer:

> What happened, where did it happen, when did it happen, and what evidence supports that
> conclusion?

without exposing secrets, changing the business architecture, or making the business path
depend on the observability stack.

## Planning base and prerequisite

Planning base:

`e29296d98fd28287cde307700018359b88385883`

This is the M6 closeout merge commit.

M6 post-merge baseline workflow `34747634769`: **SUCCESS**.

The M6 closeout boundary is therefore fully green before M7 implementation begins.

M6 left the live environment in this state:

- seven-role runtime retained and healthy:
  `edge-01`, `app-01`, `db-01`, `storage-01`, `storage-02`,
  `storage-03`, `ops-01`;
- runtime OpenTofu plan: no changes, detailed exit code 0;
- owner-bootstrap OpenTofu plan: no changes;
- final deployed M6 release:
  `9d5fda9871e479e05dc4641fccf7dea3145d2ad6`;
- final HTTPS/API/Garage business smoke: passed;
- runtime intentionally retained for immediate M7 work.

Do not recreate or destroy the existing seven-role runtime during M7 planning.

## Frozen architecture boundary

M0 already defines a separate observability failure domain:

```text
edge/app/db/storage telemetry
          │
          ▼
       obs-01
          │
          ├─ Prometheus
          ├─ Loki
          ├─ Tempo
          ├─ Grafana
          └─ Alertmanager
```

Grafana Alloy is the collection/forwarding layer.

The M0 freeze explicitly states:

- `obs-01` is a single known SPOF;
- observability HA is out of scope;
- failure of `obs-01` must **not** affect the business data path;
- app, DB, storage, observability, backup, and ops nodes have no public service ingress;
- administrative access uses the controlled operations/IAP path.

M7 implements this frozen boundary. It does not introduce an ADR-level architecture
change.

## Non-goals

M7 does **not** own:

- representative M/S/L workload generation;
- k6 performance baselines;
- query/index optimization;
- arbitrary application refactoring to create prettier traces;
- Redis, Kafka, Elasticsearch, Kubernetes, managed monitoring services, or another
  datastore;
- production SLO/SLA claims;
- external paging/SMS/email notification integration;
- observability HA;
- backup/PITR/DR;
- broad fault injection beyond the one observability-isolation check required by the
  frozen architecture;
- public Grafana/Prometheus/Loki/Tempo exposure;
- logging request/response bodies, credentials, session/CSRF values, attachment contents,
  or other sensitive material.

A bounded synthetic request sequence is allowed only to prove telemetry flow. It is not a
performance workload.

## Design principles

### 1. Observability must be out of the business path

Telemetry export must be asynchronous/bounded and fail open from the business-service
perspective.

If `obs-01`, Prometheus, Loki, Tempo, Alertmanager, or Alloy becomes unavailable:

- public HTTPS/API behavior must continue;
- PostgreSQL/Garage business writes must continue;
- telemetry may be delayed or dropped;
- the application must not wait indefinitely on telemetry delivery.

This invariant is explicitly verified before M7 closeout.

### 2. Private-by-default

`obs-01` has no public IP.

Telemetry listeners accept traffic only from intended private role tags.

Grafana is not opened to the Internet. Operator access is through the existing controlled
operations/IAP path, preferably a local tunnel through `ops-01` to the private Grafana
listener.

Prometheus, Loki, Tempo, Alertmanager, and Alloy debug/admin interfaces are not public
service endpoints.

### 3. Stable low-cardinality labels

Prometheus labels may include stable dimensions such as:

- service;
- node;
- role;
- environment;
- HTTP method;
- route template;
- response status/outcome.

Do not use these as metric labels:

- application ID;
- user ID/username;
- attachment/object key;
- request/correlation ID;
- raw URL/query string;
- exception message;
- arbitrary business text.

Correlation/request IDs may appear as log fields or trace attributes but not high-cardinality
metric labels.

### 4. No sensitive telemetry

Never record:

- passwords;
- session cookies;
- CSRF tokens;
- Garage access/secret keys;
- DB passwords;
- SOPS/age material;
- attachment bodies;
- request/response bodies.

Synthetic actor/business identifiers are not required for M7 telemetry and should be
omitted unless a later experiment demonstrates a concrete need.

### 5. Configuration is repository-owned

Observable behavior, dashboards, alert rules, Alloy pipelines, and stack configuration
must be reproducible from Git.

Manual Grafana dashboard editing is not the source of truth.

## Target runtime topology

### Existing nodes

Keep the current seven nodes unchanged except for observability configuration.

### New node: `obs-01`

Add one private Compute Engine VM:

- role: `observability`;
- proposed private IP: `10.40.0.60`;
- zone: `asia-northeast3-a`;
- no public access configuration;
- tags: `arp-observability`, `arp-managed`;
- reuse the existing workload service-account boundary unless implementation proves a
  narrower/new identity is required;
- initial size: `e2-standard-2` so the full single-node observability stack has adequate memory headroom;
- use a 20 GiB `pd-standard` boot disk for OS/configuration so M7 does not consume additional Seoul SSD quota;
- add a 40 GiB `pd-standard` data disk mounted at `/srv/observability` for
  Prometheus/Loki/Tempo/Grafana runtime data.

Do not silently resize existing business nodes.

### Free Trial resource and quota strategy

This project may spend the available Google Cloud Free Trial credit when doing so preserves
useful failure domains, measurement isolation, or recovery evidence. Cost is controlled by
runtime duration rather than collapsing architectural roles.

M6 live evidence recorded these relevant `asia-northeast3` limits:

- E2 CPUs: 32;
- instances: 8;
- in-use addresses: 4;
- SSD total: 250 GiB.

M7 intentionally consumes the eighth Seoul instance slot with `obs-01`. The retained
`storage-03` workaround (`e2-small` plus `pd-standard` boot) remains. `obs-01` uses
`pd-standard` for both its 20 GiB boot disk and 40 GiB observability data disk so the
existing SSD-backed footprint is not pushed beyond the recorded 250 GiB limit.

Later temporary resources follow ADR-002 rather than dismantling M7:

- `loadgen-01`: another region by default, preferably Tokyo;
- `backup-01`: another region by default when introduced;
- temporary DR verification VMs: another region by default;
- `app-02`: placement follows the actual scale-out experiment and is not automatically
  moved cross-region.

Before M7 live apply, rerun the read-only quota check and review the exact OpenTofu plan.
Do not assume historical quota guarantees current capacity.

If `obs-01` itself becomes CPU/memory/disk constrained during M7 verification, capture
that evidence before resizing it. A measured `obs-01` size correction is allowed; it is
not a business-performance result.

### Initial retention

Use intentionally short project retention rather than pretending to operate a production
archive:

- Prometheus: approximately 3 days;
- Loki: approximately 72 hours;
- Tempo: approximately 24 hours.

The 40 GiB data disk and the retention values are the initial M7 contract. Resize or
retention changes are allowed only after measured `obs-01` resource pressure or quota
evidence is captured, and the reason must be recorded.

Durable experiment evidence belongs in sanitized repository evidence documents, not in
indefinitely retained observability storage.

## Network contract

Prefer node-local collection with Alloy and private push to `obs-01`.

Expected private telemetry paths:

- metrics remote-write → Prometheus;
- logs → Loki;
- OTLP traces → Tempo.

Only the required ports are opened from the relevant role tags to
`arp-observability`:

- Prometheus remote-write: TCP 9090;
- Loki ingest: TCP 3100;
- Tempo OTLP: TCP 4317/4318.

Grafana TCP 3000 is reachable only from the `arp-ops` source tag. Prometheus/Loki/Tempo
query/admin ports are not opened for operator browsing from the Internet.

Grafana access is restricted to the operations path. Do not add a public Grafana firewall
rule.

Where a source can be scraped locally, keep the source listener on loopback:

- Spring Boot management/Prometheus endpoint on `127.0.0.1:9091`;
- Garage admin/metrics endpoint on loopback where supported by Garage 2.4.1;
- local system metrics/exporters.

This avoids creating new cross-node scrape surfaces on the business VMs.

## Collection model

Grafana Alloy is the default node-local collector.

Use Alloy components where they reduce standalone exporter sprawl:

- `prometheus.exporter.unix` for Linux host metrics;
- `prometheus.exporter.postgres` for PostgreSQL operational metrics;
- `loki.source.journal` for systemd-managed service logs;
- `loki.source.file` only for required file-based logs such as Nginx access/error logs;
- OTLP receiver/exporter components for application traces;
- Alloy self-metrics for pipeline health.

Do not add a second observability agent unless Alloy cannot satisfy a required signal.

Official implementation references:

- Spring Boot 4.1.1 observability:
  https://docs.spring.io/spring-boot/reference/actuator/observability.html
- Spring Boot metrics:
  https://docs.spring.io/spring-boot/reference/actuator/metrics.html
- Spring Boot tracing:
  https://docs.spring.io/spring-boot/4.1/reference/actuator/tracing.html
- Alloy Unix exporter:
  https://grafana.com/docs/alloy/latest/reference/components/prometheus/prometheus.exporter.unix/
- Alloy PostgreSQL exporter:
  https://grafana.com/docs/alloy/latest/reference/components/prometheus/prometheus.exporter.postgres/
- Alloy journal source:
  https://grafana.com/docs/alloy/latest/reference/components/loki/loki.source.journal/
- Alloy file source:
  https://grafana.com/docs/alloy/latest/reference/components/loki/loki.source.file/

Pinned repository versions must be selected explicitly during implementation; never use
floating `latest` container tags in the final Ansible/runtime configuration.

## Signal requirements

### Host metrics

Collect on edge/app/db/storage/obs nodes at minimum:

- CPU;
- load;
- memory;
- filesystem capacity/free space;
- disk I/O;
- network I/O;
- process/service availability where useful.

`ops-01` host telemetry is optional in the first slice because the frozen evidence path
focuses on edge/app/db/storage → obs. Add it only if it materially improves operation of
the retained environment.

### Edge

Required evidence:

- Nginx access/error logs centralized in Loki;
- request method/path-without-query/status/request time/upstream time;
- a technical request ID where practical;
- no cookies, authorization headers, query strings, or request bodies in access logs;
- public HTTPS availability represented by a simple probe/metric if this can be provided
  without a new standalone monitoring product.

Do not install a large Nginx metrics module merely for M7.

### Spring Boot application

Current application has no Actuator/Micrometer observability dependencies.

M7 may add the minimum Spring Boot-supported dependencies/configuration for:

- Actuator;
- Prometheus-format Micrometer metrics;
- Micrometer/OpenTelemetry tracing with OTLP export.

The intended local path is:

```text
Spring management 127.0.0.1:9091 /actuator/prometheus
          │ scrape
          ▼
      Alloy on app-01 ──remote_write──> Prometheus on obs-01

Spring OTLP traces ──> Alloy 127.0.0.1:4318 ──OTLP──> Tempo on obs-01
```

Expose the management listener only on loopback or an otherwise explicitly private local
boundary. Do not proxy `/actuator/**` through public Nginx.

At minimum verify:

- JVM/process metrics;
- HTTP server request count/duration/status;
- datasource pool metrics where available;
- Spring request traces reaching Tempo.

Do not claim JDBC/S3 child-span coverage unless it is actually observed.

Use a bounded default tracing sample probability suitable for a small project. A temporary
higher sample rate is allowed for M7 verification but must not silently become a
high-volume M8 default.

Application logs should include trace/span correlation from the supported Spring tracing
path where available.

### PostgreSQL

Create a dedicated least-privileged monitoring login rather than reusing the application
password. Manage its credential through the existing SOPS/age runtime-secret boundary.

Grant only the PostgreSQL monitoring privileges needed for metrics.

Collect operational metrics such as:

- connection counts;
- transaction activity;
- locks/deadlocks;
- buffer/cache/checkpoint activity exposed by the exporter;
- database size/state;
- process/host resource state.

M7 should also prepare `pg_stat_statements` for later M8/M9 evidence because the frozen
project execution path explicitly requires:

`workload/Grafana/trace → pg_stat_statements → SQL → EXPLAIN (ANALYZE, BUFFERS)`.

Rules:

- PostgreSQL configuration such as `shared_preload_libraries` is managed through Ansible;
- creating the extension inside the application database is a schema change and therefore
  must use a Flyway migration;
- no manual `CREATE EXTENSION` shortcut;
- do not add speculative indexes in M7;
- do not interpret query statistics as a performance bottleneck before M8 workload.

### Garage

Keep the pinned Garage deployment and three-node replication architecture.

Enable only the minimum local/admin metrics capability supported by the pinned Garage
release. Prefer loopback-local metrics collection through Alloy rather than exposing the
Garage admin interface across the VPC.

If the pinned Garage release requires a metrics token, generate/store it through SOPS/age
and never commit it.

Collect enough evidence for later Garage failure experiments:

- node/cluster health;
- RPC/connectivity errors;
- storage capacity;
- request/storage error counters exposed by Garage.

Centralize Garage logs without granting unnecessary broad Docker access to the Alloy
process. Prefer a controlled logging-driver/journal path if practical.

Do not enable Garage distributed tracing in M7 unless it is required to answer an actual
later experiment and the trace-context behavior is verified.

### Observability stack self-health

Monitor `obs-01` and the telemetry pipeline itself:

- Prometheus ingestion/remote-write health;
- Loki ingestion health;
- Tempo ingestion health;
- Alloy failed/retried/dropped telemetry where exposed;
- `obs-01` CPU/memory/disk pressure.

An observability system that silently drops data is not acceptable evidence infrastructure.

## Dashboard scope

Provision dashboards from repository files.

Keep the first dashboard set small:

1. **System Overview**
   - node up/down;
   - CPU/memory/disk;
   - public/app health;
   - telemetry pipeline health.

2. **Application/API**
   - request rate;
   - error/status distribution;
   - request duration;
   - JVM/process;
   - datasource pool;
   - trace links/drilldown where supported.

3. **PostgreSQL**
   - connections;
   - transactions;
   - locks/deadlocks;
   - cache/checkpoint/activity metrics;
   - host disk/resource state.

4. **Garage**
   - three-node health;
   - capacity;
   - RPC/storage/request errors exposed by Garage.

Do not build performance-result dashboards before M8 produces representative workloads.

## Alert scope

Alertmanager is required because it is part of the frozen stack, but M7 does not pretend
to operate a 24x7 paging service.

Initial alert rules should be conservative and structural:

- monitored target/collector unavailable;
- application health unavailable;
- critically low filesystem free space;
- PostgreSQL unavailable;
- Garage node/cluster health problem when a reliable metric exists;
- observability ingestion/pipeline failure.

Do not invent latency/error SLO alerts from nonexistent production requirements.

A local/no-external-notification receiver is acceptable for M7. Verification must prove a
test alert reaches Alertmanager and clears after recovery.

## Correlation model

Use technical correlation only.

Preferred fields:

- timestamp;
- service;
- node;
- environment;
- trace ID/span ID for application logs;
- bounded request ID across Nginx → Spring when implemented;
- HTTP method;
- route/path without query string;
- response status;
- duration.

Do not promote request IDs or trace IDs into Prometheus/Loki labels with unbounded
cardinality.

## Implementation phases

### Phase 1 — Repository observability foundation

Status: **IN REVIEW**

Create the repository-side foundation only.

Scope:

- extend OpenTofu for `obs-01` without replacing the existing seven nodes;
- add the observability role/machine-size variables and private address;
- add only required telemetry/Grafana-operations firewall paths;
- extend inventory/Ansible grouping for `observability`;
- create initial `monitoring/` configuration structure;
- add static validation proving:
  - `obs-01` has no public IP;
  - existing edge/app/db/storage addresses/topology are unchanged;
  - Grafana is not Internet-exposed;
  - M7 ports are private/tag-restricted;
- do not apply live GCP changes in this phase.

Done condition:

- exact-head CI passes;
- OpenTofu validation/plan fixtures show one bounded observability-node addition plus
  intended private firewall additions only;
- no runtime apply has occurred.

Current PR #58 implementation adds the repository foundation only. Its final reviewed
contract includes:

- private `obs-01` at `10.40.0.60`;
- `e2-standard-2`;
- 20 GiB `pd-standard` boot + 40 GiB `pd-standard` data disk;
- tag-restricted telemetry ingress;
- Grafana 3000 only from `arp-ops`;
- generated `observability` inventory group;
- repository-owned `monitoring/` structure;
- M7 static CI contract.

No live GCP apply belongs to Phase 1.

### Phase 2 — Central observability stack and Alloy baseline

Create reproducible Ansible/config for:

- Prometheus;
- Loki;
- Tempo;
- Grafana;
- Alertmanager;
- Alloy;
- datasource provisioning;
- repository-managed dashboards/rules;
- retention/resource limits.

Add config validation to CI where the upstream binaries support it.

Do not configure application/DB/Garage secrets in repository plaintext.

Done condition:

- configs are pinned/reproducible and validation is green repository-side;
- no public listeners are introduced by infrastructure rules.

### Phase 3 — Source instrumentation and secure telemetry pipelines

Implement the minimum source changes:

- Alloy on required existing nodes;
- host metrics;
- Nginx logs;
- Spring Boot Actuator/Prometheus/tracing;
- PostgreSQL monitoring role/metrics;
- Flyway-managed `pg_stat_statements` extension plus required PostgreSQL config;
- Garage metrics/log collection;
- stable labels and correlation fields;
- SOPS schema additions for any new runtime credentials.

Preserve all M1–M6 behavior and release mechanics.

Done condition:

- focused application/config/security tests are green;
- public Nginx cannot expose Actuator/collector/admin endpoints;
- no secret or body logging is introduced.

### Phase 4 — Live `obs-01` provisioning and telemetry activation

Use the existing controlled M6 operations path.

Sequence:

1. lock the exact reviewed main SHA;
2. run live OpenTofu plan with the retained state and existing `storage-03`
   capacity overrides;
3. review that the plan does not replace/destroy any existing seven node;
4. apply only the reviewed M7 infrastructure delta;
5. configure `obs-01` central stack;
6. create/update encrypted runtime observability secrets on the controlled path;
7. configure node-local Alloy/source telemetry;
8. apply PostgreSQL observability configuration;
9. publish/deploy the exact reviewed application release through the established M6
   immutable release handoff;
10. allow Flyway to apply any M7 migration naturally on application startup;
11. verify business HTTPS smoke before declaring observability healthy.

No manual working-tree JAR deployment.

### Phase 5 — Observability verification and evidence closeout

Verify all three signal families and the isolation invariant.

Required checks:

#### Metrics
- every expected host/source produces recent samples;
- Spring request/JVM metrics change after bounded synthetic requests;
- PostgreSQL metrics are present;
- all three Garage nodes are distinguishable;
- observability pipeline/self-health metrics are present.

#### Logs
- Nginx access/error logs appear in Loki;
- application logs appear with useful correlation fields;
- PostgreSQL/Garage operational logs required by the design are queryable;
- secrets/bodies are absent from sampled entries.

#### Traces
- a bounded application request produces a trace in Tempo;
- trace metadata identifies the service/route/status without sensitive payload data;
- Grafana can navigate/query the Tempo datasource.

#### Dashboard
- repository-provisioned dashboards load and populate from real telemetry.

#### Alert
- trigger one observability-only test condition;
- confirm Prometheus rule → Alertmanager delivery;
- recover the condition and confirm the alert clears.

#### Failure isolation
- make the central observability services unavailable in a controlled manner;
- run the existing HTTPS/API/Garage business smoke;
- confirm the business flow still passes;
- restore observability and confirm telemetry resumes.

This is a boundary invariant test, not the M10 reliability campaign.

#### Infrastructure
- final runtime OpenTofu plan reports no drift.

#### Lifecycle
- decide whether to retain the eight-node runtime for immediate M8 or destroy/stage-stop
  resources for cost control;
- record the decision explicitly.

## Verification baseline for every M7 PR

Preserve existing required checks:

- `repository-baseline`;
- `m1-application`;
- `m4-infrastructure-static`;
- `m5-frontend`;
- `m5-browser-e2e`;
- `m5-nginx-routing`;
- relevant M6 release/install/delivery static checks.

Add M7-focused verification without weakening prior jobs.

Expected new checks may include:

- `m7-observability-infrastructure-static`;
- `m7-observability-config`;
- focused Spring observability/security tests.

No M7 PR merges from a failing exact head.

## Evidence and portfolio treatment

The Portfolio Evidence Map currently treats observability as enabling infrastructure.

M7 may move that row from E0 to E2 only if real telemetry and failure-isolation behavior
are verified.

Do **not** promote M7 to an E5 primary story merely because the stack is installed.

M7's main value is making later M8–M10 observations trustworthy.

Expected closeout evidence should retain:

- exact source SHA;
- OpenTofu plan/apply scope;
- `obs-01` identity and private exposure proof;
- pinned component versions;
- sanitized datasource/target health;
- one metrics example;
- one log correlation example;
- one trace example;
- one alert delivery/clear example;
- observability-failure business-smoke result;
- final no-drift plan;
- lifecycle disposition.

## Expected repository areas

Likely M7 implementation touches:

- `infra/opentofu/`;
- `config/ansible/site.yml`;
- new Ansible observability/Alloy roles;
- `config/ansible/group_vars/`;
- `config/secrets/runtime.schema.yaml`;
- `monitoring/`;
- `app/pom.xml`;
- `app/src/main/resources/application.yml`;
- a Flyway migration only if needed for `pg_stat_statements`;
- Nginx logging configuration;
- Garage runtime configuration;
- CI/static validation scripts;
- M7 operations/evidence documentation.

Do not modify unrelated business-domain behavior merely because M7 is active.

## M7 completion criteria

M7 is complete only when all are true:

- `obs-01` exists as a private observability failure domain;
- no existing business node was unintentionally replaced;
- Prometheus/Loki/Tempo/Grafana/Alertmanager/Alloy are reproducibly configured;
- host, edge, app, DB, and Garage telemetry required by this plan is observable;
- Spring Prometheus metrics and at least one real application trace are retained;
- PostgreSQL monitoring uses a dedicated least-privileged identity;
- `pg_stat_statements` is prepared through the required Ansible/Flyway boundaries if
  included in the implementation;
- no public Actuator/Grafana/backend observability surface exists;
- bounded dashboards and structural alerts work;
- an Alertmanager test alert is delivered and clears;
- observability outage does not break the full business smoke;
- final runtime OpenTofu plan reports no drift;
- sanitized evidence is committed;
- Evidence Map maturity is updated honestly;
- runtime retain/destroy disposition is recorded;
- final exact-head CI passes;
- post-merge `main` CI passes.

M8 representative workload work must not begin before this closeout is complete.
