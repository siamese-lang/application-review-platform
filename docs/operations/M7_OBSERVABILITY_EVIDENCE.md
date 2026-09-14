# M7 Observability — Live Verification and Closeout Evidence

Status: VERIFIED / COMPLETE  
Verification date: 2026-09-14 UTC  
Final verification source revision: `cea4ca09d05efd89bcb9227c866d841968c08547`

This record contains sanitized M7 runtime evidence. It intentionally excludes passwords,
SOPS/age material, session/CSRF values, Garage credentials, request/response bodies,
attachment contents, and other secret material.

## Runtime boundary

M7 extended the retained M6 business runtime with a separate private observability failure
domain:

- `obs-01`: `10.40.0.60`, no public IP;
- Prometheus, Loki, Tempo, Grafana, Alertmanager on `obs-01`;
- Grafana Alloy as the node-local collection/forwarding layer;
- existing edge/app/db/storage/ops roles retained.

Pinned repository versions at closeout:

- Prometheus `3.13.3`;
- Loki `3.7.7`;
- Tempo `3.0.2`;
- Grafana `13.2.1`;
- Alertmanager `0.34.0`;
- Alloy `1.18.1`.

The final runtime OpenTofu plan, using the retained `storage-03` capacity overrides,
reported no changes.

## Metrics verification

Phase 5 verified recent metrics from the expected telemetry hosts and sources, including:

- host metrics across edge/app/db/storage/observability roles;
- Spring JVM and HTTP request metrics;
- PostgreSQL metrics;
- all three Garage storage nodes as distinct series;
- Prometheus/self-health;
- the private application blackbox probe.

The application probe ended with `probe_success=1` for the exact
`integrations/blackbox/application-api` selector.

## Logs and correlation

Loki verification proved:

- Nginx access logs are queryable; the error stream is queryable even when it has no
  current entries;
- PostgreSQL logs are queryable;
- Garage logs are queryable for all three storage nodes;
- application logs are queryable;
- sampled logs do not contain the prohibited secret/body material checked by the Phase 5
  privacy boundary.

Initial application-log collection was healthy but did not provide useful per-request
correlation. PR #92 added one bounded application request log and preserved request IDs in
MDC while the trace was active.

The final live correlation check produced:

- application log present;
- request ID correlation present;
- trace ID and span ID correlation present;
- correlation log privacy check passed.

The Phase 5 logs boundary then passed.

## Trace verification

A bounded request was correlated from Loki to Tempo by trace ID.

The retrieved trace identified:

- `service.name=application-review-platform`;
- request span `http get /api/v1/programs`;
- span status `STATUS_CODE_OK`.

The live trace therefore provided service, route/method context, and success status without
requiring sensitive payload data.

Grafana's provisioned Tempo datasource also successfully retrieved the same class of live
trace data.

## Grafana verification

All four repository-provisioned dashboards loaded from Grafana:

- `ARP / System Overview` — 5 panels;
- `ARP / Application API` — 5 panels;
- `ARP / PostgreSQL` — 6 panels;
- `ARP / Garage` — 3 panels.

Grafana datasource health passed for Prometheus, Loki, and Tempo.

Queries through Grafana returned real telemetry for:

- system/application health;
- application metrics;
- PostgreSQL;
- all three Garage nodes;
- Loki logs;
- Tempo traces.

## Alert delivery and clear

The existing `ARPApplicationHealthUnavailable` rule was exercised without stopping the
business application.

Only the observability-side private probe path to `app-01:8080` was temporarily rejected.
Observed sequence:

1. `probe_success` changed from 1 to 0;
2. the Prometheus alert entered `pending`;
3. after the configured five-minute `for:` duration it entered `firing`;
4. Alertmanager contained one active alert;
5. the probe path was restored;
6. `probe_success` returned to 1;
7. the Prometheus alert cleared;
8. Alertmanager returned to zero active alerts.

This verifies Prometheus rule evaluation, Alertmanager delivery, and recovery/clear behavior
without claiming an external paging service.

## Observability failure isolation

The central observability services on `obs-01` were deliberately stopped:

- Alloy;
- Prometheus;
- Alertmanager;
- Loki;
- Tempo;
- Grafana.

While they were unavailable, the existing full HTTPS business smoke passed. The smoke
covered:

- SPA root and deep-link;
- public programs API;
- applicant registration/login/session/CSRF;
- application create/edit/submit;
- Garage attachment upload and SHA-256-identical download;
- reviewer login/start/approve;
- final applicant state and status history.

The successful outage-time smoke produced application 11.

This proves the frozen M7 invariant that central observability failure does not break the
business data path.

After restoration:

- Prometheus telemetry resumed;
- Loki returned `200 OK` from `/ready`;
- Loki query/listener paths were healthy;
- a new post-ready application request was ingested by Loki on the first verification
  attempt.

The first post-restart Loki recovery check ran before Loki had become ready and therefore
did not find its one request. The later readiness check showed that this was a restart
timing artifact rather than a persistent ingestion defect.

## Live verification findings

M7 live activation/verification exposed several small gaps that were corrected rather than
hidden:

- Grafana runtime secret schema coverage was completed during live activation;
- the Alloy binary install path was corrected to guarantee executable permissions;
- the private application health probe required by the existing dashboard/alert contract
  was added;
- duplicate Spring OTLP metrics export was disabled while preserving Prometheus scrape and
  OTLP tracing;
- PostgreSQL log readability for the live Alloy process was corrected;
- Loki query-path addressing was corrected through the final private gRPC/ring
  configuration;
- application per-request trace/span/request correlation was added after live Loki evidence
  showed that startup/framework logs alone could not prove request correlation.

These corrections stayed inside the frozen M7 boundary: no new datastore, queue, cache,
public observability endpoint, or business-domain redesign was introduced.

## Infrastructure no-drift

The final controlled runtime OpenTofu plan used:

- project `application-review-platform`;
- retained `storage-03` machine override `e2-small`;
- retained `storage-03` boot disk override `pd-standard`.

Result:

`No changes. Your infrastructure matches the configuration.`

No apply was run because no drift existed.

## Lifecycle disposition

Decision: **retain the eight-node runtime for immediate M8 Workload work**.

Reason:

- M8 is the next milestone and requires the already-verified business runtime plus M7
  telemetry to establish representative baselines;
- destroying M7 now would immediately require rebuilding the same measurement substrate;
- retaining the runtime preserves measurement continuity and avoids unnecessary
  reconstruction.

This remains a bounded project decision, not an indefinite-retention commitment. M8
closeout must re-evaluate runtime cost and lifecycle again.

## Evidence maturity

M7 observability moves from E0 to **E2**.

Reason:

- the stack is not credited merely for being installed;
- real metrics/logs/traces were independently queried;
- dashboards were proven against live telemetry;
- alert firing/delivery/clear was exercised;
- the observability failure-domain invariant was tested with the full business smoke;
- telemetry recovery and final infrastructure no-drift were verified.

M7 remains enabling infrastructure rather than a primary E5 portfolio story. Its purpose is
to make M8–M10 workload, performance, and fault evidence trustworthy.

## Evidence boundary

M7 does not claim:

- observability HA;
- production SLO/SLA attainment;
- external paging;
- representative load/performance results;
- a PostgreSQL bottleneck;
- optimization gains;
- broad reliability/fault-injection coverage.

Those remain later-milestone concerns.
