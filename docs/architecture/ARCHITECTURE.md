# ARCHITECTURE — M0 Frozen Baseline

Status: FROZEN

## Architectural boundaries

1. Business / Domain
2. Edge
3. Application
4. Relational Data
5. Object Storage
6. Backup / Recovery
7. Observability
8. Operations / Infrastructure
9. Verification Harness

## Target topology

```text
Internet
  │ HTTPS
  ▼
edge-01: Nginx
  │ private network
  ▼
app-01: Spring Boot + Spring Security + Spring Session JDBC
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

## Network principles

- `edge-01` is the public ingress.
- App, DB, storage, observability, backup, and ops nodes have no public inbound service exposure.
- Administrative access uses IAP.
- Private outbound dependency/image access uses Cloud NAT.
- Firewall rules permit only required service paths.

## Technology baseline

Java 21; Spring Boot 4.1.x; Spring MVC + Thymeleaf; Spring Security; Spring Session JDBC; Spring Data JPA; Flyway; PostgreSQL; Garage; Nginx; Prometheus; Loki; Tempo; Grafana; Alertmanager; Grafana Alloy; pgBackRest; k6; OpenTofu; Ansible; GitHub Actions; Docker/container runtime; SOPS + age; GHCR.

## GCP boundary

GCP is primarily the IaaS execution environment. Compute Engine, Persistent Disk, VPC, Firewall, IAP, and Cloud NAT are allowed baseline capabilities. Cloud SQL, GKE, managed Redis, and managed application storage are not baseline components.

## Failure-domain principle

Do not collapse Nginx, Spring, PostgreSQL, Garage, and observability into one all-in-one VM for final operational tests. Known single points of failure such as the single PostgreSQL primary and `obs-01` are documented limitations, not hidden claims of HA.
