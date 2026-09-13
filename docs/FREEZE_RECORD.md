# M0 FREEZE RECORD

Baseline date: 2026-09-09  
Status: FROZEN EXCEPT AS AMENDED BY ACCEPTED ADRS

This record resolves the known M0 tensions so later implementation does not reinterpret them silently.

1. **OSS vs GCP:** application-level systems use the frozen OSS stack; GCP-native compute/network/disk capabilities may provide the IaaS substrate.
2. **Garage topology:** development may use one Garage node with replication 1; final storage reliability testing uses three nodes with replication across the cluster.
3. **PITR vs full DR:** PostgreSQL PITR is an independent database experiment; whole-system recovery uses a verified maintenance checkpoint for DB/object consistency.
4. **WAS scale-out vs session:** Spring Session JDBC keeps session state outside an individual WAS. `app-02` is temporary unless evidence justifies otherwise.
5. **DB/object atomicity:** attachment state plus reconciliation handles cross-store consistency; no distributed transaction or queue is introduced for this purpose.
6. **Cost vs separation:** preserve meaningful failure/measurement boundaries and reduce VM-hours instead of collapsing the final system into one all-in-one VM.
7. **Weak local PC:** GitHub/Codex/Actions/GCP/`ops-01` form the working toolchain; project success must not depend on a powerful local environment.
8. **Single PostgreSQL primary:** this is a known SPOF. Recovery is measured; automatic HA is not claimed.
9. **Single backup repository:** simultaneous loss of `backup-01` and the whole region is out of scope.
10. **Single observability node:** observability HA is out of scope, and `obs-01` failure must not affect the business data path.

## Accepted amendments

### ADR-001 — REST API + React SPA browser boundary (2026-09-11)

The original M0 choice of Spring MVC + Thymeleaf as the final browser presentation and the blanket React-SPA non-goal are superseded.

The accepted replacement is:

- React + TypeScript + Vite static frontend;
- versioned Spring Boot REST API under `/api/v1`;
- Nginx serves the static frontend and proxies API traffic on one production origin;
- Spring Security session authentication, Spring Session JDBC, and CSRF protection remain;
- no JWT, Node production server, separate frontend VM, or microservice split is introduced without a separate demonstrated requirement.

The detailed rationale and consequences are recorded in `docs/architecture/ADR-001-web-api-spa.md`.

This amendment deliberately occurs after M4 and before future delivery/observability/workload work so those milestones target the final browser/API boundary.

### ADR-004 — Persistent Seoul runtime + temporary cross-region experiment resources (2026-09-13)

The project keeps the primary service/runtime failure domains in `asia-northeast3`
(Seoul), including the M7 `obs-01` observability node.

The Google Cloud Free Trial quota recorded during M6 allows eight Seoul instances. M7
intentionally consumes the eighth slot. Temporary experiment/recovery resources such as
`loadgen-01`, `backup-01`, and DR verification VMs therefore use another region by
default, with `asia-northeast1` (Tokyo) preferred when quota/capacity permits.

This does not weaken the M0 cost/separation rule. Available promotional credit may be used
to preserve meaningful failure and measurement boundaries; runtime duration is controlled
instead of collapsing roles. A temporary application-tier `app-02` remains subject to
the actual scale-out experiment and is not automatically moved cross-region.

Detailed rationale and measurement consequences are recorded in
`docs/architecture/ADR-004-gcp-resource-placement.md`.

## ADR boundary

An approved ADR is required before adding or replacing a database, Redis/cache, queue, primary object storage product, Kubernetes, authentication system, microservice split, managed application cloud service, DB failover design, backup architecture, or another change that contradicts an explicit frozen/non-goal architectural boundary.

Bug fixes, UI copy, tests, measured indexes, metrics/dashboards, patch releases, timeout values, and VM-size experiments do not require an ADR unless they change one of the frozen boundaries above.
