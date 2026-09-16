# Application Review Platform

지원사업의 **신청 → 제출 → 심사 → 보완 → 승인·반려** 흐름을 구현하고, 같은 시스템을 실제 GCP IaaS 환경에서 배포·관측·부하·장애·복구까지 검증한 개인 프로젝트입니다.

기술을 많이 붙이는 것보다 **측정된 문제를 좁히고, 필요한 범위만 변경한 뒤 같은 조건에서 다시 검증하는 과정**을 중심으로 설계했습니다.

> 이 프로젝트는 production-like 개인 프로젝트입니다. 사용자, 조직, 신청서, 파일, 부하 데이터는 모두 synthetic이며 실제 운영 고객·트래픽·SLA를 주장하지 않습니다.

## Portfolio highlights

| 문제 | 확인한 근거와 조치 | 검증 결과 |
| --- | --- | --- |
| PostgreSQL reviewer queue 병목 | 10만 건 합성 데이터 부하 → `pg_stat_statements` / `EXPLAIN (ANALYZE, BUFFERS)` → 조건·정렬 경로를 지원하는 단일 Flyway index | W3 non-file p95 **2.07 s → 80.9 ms**, DB CPU 평균 **90.9% → 37.1%** |
| 3노드 Garage인데 endpoint 하나가 죽으면 첨부 기능 실패 | non-endpoint/node endpoint fault 비교 → fixed S3 endpoint가 실제 SPOF임을 분리 → app-local Nginx failover proxy | 동일 storage-01 fault에서 attachment error **28.692% → 0%**, 새 lifecycle residue **0** |
| 프로세스 재기동이 아니라 실제 업무 상태의 복구 가능성 | PostgreSQL PITR + DB/Garage checkpoint + 별도 Tokyo recovery environment | PRE 포함/POST 제외, DB PITR **27.229 s**, restored business/history/audit/attachment integrity **PASS** |

상세 포트폴리오: **[PROJECT_PORTFOLIO.md](docs/portfolio/PROJECT_PORTFOLIO.md)**  
면접·이력서 설명: **[INTERVIEW_PACKET.md](docs/portfolio/INTERVIEW_PACKET.md)**  
세 사례 선정 근거: **[M12_STORY_SELECTION.md](docs/portfolio/M12_STORY_SELECTION.md)**

## Product workflow

Public entry:

`program discovery → applicant registration/login → private application workflow`

Core application state:

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

- **APPLICANT** — 프로그램 조회, 가입/로그인, 신청서 작성·수정, 첨부파일 관리, 제출·재제출, 상태/결과 확인
- **REVIEWER** — 제출 건 조회, 심사 시작/claim, 첨부 확인, 보완 요청, 승인·반려
- **ADMIN** — 프로그램 작성·게시, 사용자/신청/상태이력/audit 운영 조회

권한과 상태 전이 규칙은 UI가 아니라 service/domain 계층에서 검증합니다. 상태 변경과 history는 하나의 relational transaction으로 처리하며, 동시 수정/claim에는 optimistic locking을 사용합니다.

## Final architecture

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
  └─→ OpenTofu / Ansible / release / verification tooling
```

Persistent service/runtime roles are separated so edge, application, database, object storage, observability, and operations have distinct access/failure boundaries. The application itself remains a modular monolith; microservices or Kubernetes were not added without a measured need.

The final application S3 endpoint is the app-local proxy, not one fixed Garage node. PostgreSQL remains a single primary; this project does not claim database HA.

Architecture detail: **[ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md)**  
Accepted decisions: [ADR-001](docs/architecture/ADR-001-web-api-spa.md), [ADR-002](docs/architecture/ADR-002-account-lifecycle.md), [ADR-003](docs/architecture/ADR-003-program-lifecycle.md), [ADR-004](docs/architecture/ADR-004-gcp-resource-placement.md), [ADR-005](docs/architecture/ADR-005-garage-endpoint-failover.md)

## Integrity and operations boundaries

### Identity / authorization

- Spring Security session authentication + Spring Session JDBC
- same-origin SPA/API through Nginx
- CSRF protection on browser mutations
- public registration can create only `APPLICANT`
- `REVIEWER` / `ADMIN` are controlled bootstrap identities
- ownership, role, intake-window, and state-transition checks remain server-side

The project does not claim real identity proofing, email verification, MFA, SSO/OIDC, or password-reset delivery.

### Relational data

- PostgreSQL schema changes are Flyway-only
- business transition + history use one transaction
- PK/FK/UNIQUE/NOT NULL/CHECK constraints are part of correctness
- optimistic locking protects concurrent claim/update paths

### Attachments

- PostgreSQL stores metadata; Garage stores object bytes
- lifecycle state is explicit
- upload/download integrity uses SHA-256
- object replication, client endpoint availability, and independent backup are treated as different concerns

### Delivery / evidence

A reviewed source SHA is packaged into paired backend/frontend release identity with checksums and immutable artifact identity. A real schema-compatible B → A rollback was executed and full business/attachment smoke was revalidated.

Prometheus/Loki/Tempo/Grafana/Alertmanager/Alloy are used as evidence infrastructure for workload and fault experiments rather than as standalone portfolio claims.

Supporting release/rollback evidence: **[M6_IMMUTABLE_RELEASE_ROLLBACK_EVIDENCE.md](docs/portfolio/M6_IMMUTABLE_RELEASE_ROLLBACK_EVIDENCE.md)**

## Evidence-backed cases

### 1. PostgreSQL performance diagnosis

The peak-load problem was narrowed from system-level latency to exact SQL and execution-plan behavior before making a change. Predicate-only simplification was tested and rejected; pool/VM/cache expansion was not used to hide the measured access-path problem.

Evidence: **[M8_POSTGRESQL_QUERY_BOTTLENECK_EVIDENCE.md](docs/portfolio/M8_POSTGRESQL_QUERY_BOTTLENECK_EVIDENCE.md)**

### 2. Garage endpoint reliability

A controlled fault comparison showed that Garage replication preserved object copies while the application still depended on one fixed endpoint. The correction was limited to that failure boundary and then tested with the original fault again.

Evidence: **[M10_GARAGE_ENDPOINT_FAILOVER_EVIDENCE.md](docs/portfolio/M10_GARAGE_ENDPOINT_FAILOVER_EVIDENCE.md)**

### 3. Disaster recovery correctness

PostgreSQL PITR was verified independently, then PostgreSQL metadata and Garage object bytes were captured through an explicit maintenance checkpoint and rebuilt into fresh recovery infrastructure. Recovery success was judged by business/history/audit/attachment invariants, not by process startup alone.

Evidence: **[M11_DISASTER_RECOVERY_EVIDENCE.md](docs/portfolio/M11_DISASTER_RECOVERY_EVIDENCE.md)**

## Claim boundary

Verified in this project:

- support-program application/review workflow and server-side business rules
- authorization, history/audit, optimistic-lock, and attachment-integrity boundaries
- exact release identity and schema-compatible rollback
- bounded synthetic workload and direct PostgreSQL plan analysis
- bounded single-Garage-node fault and same-fault correction verification
- independent PostgreSQL PITR
- separate-environment DB/object restore and business-integrity verification

Not claimed:

- real production users or production traffic
- contractual SLA/SLO
- enterprise identity verification
- PostgreSQL automatic failover/HA
- continuous multi-region availability
- simultaneous multi-node/region failure tolerance beyond retained tests
- full-DR end-to-end RTO or effective full-system RPO
- production capacity inferred from synthetic load

## Repository guide

| 목적 | 문서 |
| --- | --- |
| 3–5분 프로젝트 파악 | [PROJECT_PORTFOLIO.md](docs/portfolio/PROJECT_PORTFOLIO.md) |
| 이력서·면접 설명 | [INTERVIEW_PACKET.md](docs/portfolio/INTERVIEW_PACKET.md) |
| 최종 3개 사례 선정 근거 | [M12_STORY_SELECTION.md](docs/portfolio/M12_STORY_SELECTION.md) |
| 전체 evidence maturity / 후보 | [PORTFOLIO_EVIDENCE_MAP.md](docs/portfolio/PORTFOLIO_EVIDENCE_MAP.md) |
| 최종 architecture | [ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md) |
| durable project rules | [PROJECT_EXECUTION.md](docs/PROJECT_EXECUTION.md) |
| 현재 AI 작업 checkpoint | [AI_PROJECT_STATE.md](docs/AI_PROJECT_STATE.md) |

## Technology summary

React / TypeScript / Vite · Nginx · Java 21 / Spring Boot / Spring Security / Spring Session / JPA · PostgreSQL / Flyway · Garage · Prometheus / Loki / Tempo / Grafana / Alertmanager / Alloy · k6 · pgBackRest · GCP Compute Engine / VPC / Persistent Disk · OpenTofu / Ansible · GitHub Actions / GHCR · SOPS + age

## Project status

M1–M11 implementation, workload, fault, and recovery milestones are complete.

M12 Portfolio is active:
- Phase 1 story selection — complete
- Phase 2 final-system narrative — complete
- Phase 3 interview/application compression — complete
- Phase 4 public repository presentation — active
- Phase 5 runtime lifecycle / final closeout — pending

The persistent Seoul runtime remains retained only until the M12 Phase 5 lifecycle decision. Temporary M10/M11 load, backup, PITR, and full-DR resources have already been removed.

Completed milestone plans and historical operational evidence remain under `docs/plans/completed/` and `docs/operations/`.
