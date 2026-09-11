# ARCHITECTURE — M0 Baseline amended by ADR-001

Status: FROZEN EXCEPT AS AMENDED BY ACCEPTED ADRS

The original M0 architecture remains the baseline. `ADR-001-web-api-spa.md` supersedes the original final-browser choice of Spring MVC + Thymeleaf and the blanket React-SPA non-goal. Other M0 boundaries remain in force.

## Architectural boundaries

1. Browser Presentation
2. HTTP API / Application
3. Business / Domain
4. Edge
5. Relational Data
6. Object Storage
7. Backup / Recovery
8. Observability
9. Operations / Infrastructure
10. Verification Harness

## Target topology

```text
Internet
  │ HTTPS
  ▼
edge-01: Nginx
  ├─ /, /assets/** → versioned React/Vite static release
  └─ /api/v1/**    → app-01: Spring Boot REST API + Spring Security + Spring Session JDBC
                          ├─ JDBC → db-01: PostgreSQL
                          └─ S3 API → Garage: storage-01 / storage-02 / storage-03

DB backup/WAL ─────┐
Garage object copy ├→ backup-01
OpenTofu state ────┘

edge/app/db/storage telemetry → obs-01
Prometheus / Loki / Tempo / Grafana / Alertmanager

GitHub/Codex → ops-01
OpenTofu / Ansible / deploy scripts / encrypted secrets / state → GCP
```

Temporary resources only when required: `loadgen-01` for k6, `app-02` for scale-out experiments, and new DR VMs for recovery exercises.

## Browser and API principles

- React + TypeScript is the supported browser presentation after M5.
- Vite produces static assets; no Node/SSR process is required in production.
- Nginx serves the SPA and proxies `/api/v1/**` to the private Spring application.
- The browser and API share one production origin. CORS is not opened broadly merely because the frontend is React.
- Local frontend development uses a development proxy for `/api` unless a real cross-origin scenario is intentionally being tested.
- REST controllers expose explicit DTOs and delegate business rules to application/domain services.
- JPA entities are not serialized as the external API contract.
- State transitions may use explicit command endpoints when that is clearer than forcing transition semantics into generic CRUD.
- Browser visibility rules never replace server-side ownership, role, and state-transition checks.

## Network principles

- `edge-01` is the only public service ingress.
- App, DB, storage, observability, backup, and ops nodes have no public inbound service exposure.
- Administrative access uses IAP.
- Private outbound dependency/image access uses Cloud NAT.
- Firewall rules permit only required service paths.
- A separate frontend VM is not introduced because the SPA is a static release served by the existing edge.

## Technology baseline

Java 21; Spring Boot 4.1.x; Spring REST/MVC infrastructure; Spring Security; Spring Session JDBC; Spring Data JPA; Flyway; PostgreSQL; Garage; React; TypeScript; Vite; Nginx; Prometheus; Loki; Tempo; Grafana; Alertmanager; Grafana Alloy; pgBackRest; k6; OpenTofu; Ansible; GitHub Actions; Docker/container runtime; SOPS + age; GHCR.

Thymeleaf migration presentation code was removed in M5. React/Vite static assets served by Nginx are the supported browser presentation.

## GCP boundary

GCP is primarily the IaaS execution environment. Compute Engine, Persistent Disk, VPC, Firewall, IAP, and Cloud NAT are allowed baseline capabilities. Cloud SQL, GKE, managed Redis, and managed application storage are not baseline components.

The frontend static build remains part of the edge release rather than becoming a new managed hosting dependency merely for convenience.

## Failure-domain principle

Do not collapse Nginx, Spring, PostgreSQL, Garage, and observability into one all-in-one VM for final operational tests. Known single points of failure such as the single PostgreSQL primary and `obs-01` are documented limitations, not hidden claims of HA.

The frontend static files do not create a meaningful independent runtime failure domain and therefore do not justify a separate VM.

## API and deployment evolution

The browser/API boundary must be settled before Operations, Observability, Workload, and Performance milestones build around it.

Backend and frontend are separate artifacts from the same repository revision. Later deployment automation must be able to identify and roll back both artifacts while respecting additive database migration policy.
