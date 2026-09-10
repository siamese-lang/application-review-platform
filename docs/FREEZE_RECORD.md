# M0 FREEZE RECORD

Baseline date: 2026-09-09  
Status: FROZEN

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

## ADR boundary

An approved ADR is required before adding or replacing a database, Redis/cache, queue, primary object storage product, Kubernetes, authentication system, microservice split, managed application cloud service, DB failover design, or backup architecture.

Bug fixes, UI copy, tests, measured indexes, metrics/dashboards, patch releases, timeout values, and VM-size experiments do not require an ADR unless they change one of the frozen boundaries above.
