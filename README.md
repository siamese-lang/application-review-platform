# Application Review Platform

지원사업 신청·심사 업무 흐름을 구현하고 GCP IaaS 환경에서 성능, 데이터 정합성, 장애 영향, 백업 및 복구를 측정·검증하는 개인 프로젝트입니다.

## Current status

- M0 design baseline: frozen
- P0-A tool onboarding: complete
- P0-B repository bootstrap: complete
- P0-C GCP readiness: complete
- Current implementation milestone: M1 Business MVP

This project is **production-like**, not a claim of real production operation. All users, organizations, applications, workloads, and measurements are synthetic unless explicitly recorded otherwise.

## GCP readiness baseline

- Project ID: `application-review-platform`
- Primary region: `asia-northeast3`
- Primary zone: `asia-northeast3-a`
- Runtime VM fleet: not provisioned yet

See `docs/operations/GCP_BASELINE.md` for the owner-confirmed readiness record and M4 infrastructure conventions.

## Core business flow

`DRAFT → SUBMITTED → IN_REVIEW → NEEDS_REVISION → SUBMITTED` or `IN_REVIEW → APPROVED/REJECTED`

Roles: `APPLICANT`, `REVIEWER`, `ADMIN`.

## Source of truth

Read `AGENTS.md` first. The frozen M0 documents under `docs/` define product scope, domain rules, architecture, security, data, recovery, workload, and non-goals. A decision made only in chat is not project state until it is committed to this repository.

## Planned stack

Java 21, Spring Boot 4.1.x, Spring MVC/Thymeleaf, Spring Security, Spring Session JDBC, Spring Data JPA, Flyway, PostgreSQL, Garage, Nginx, Prometheus, Loki, Tempo, Grafana, Alertmanager, Grafana Alloy, pgBackRest, k6, OpenTofu, Ansible, GitHub Actions, GHCR, SOPS + age.

## Milestones

M1 Business MVP → M2 Data Integrity → M3 Attachment → M4 Cloud Deployment → M5 Operations → M6 Observability → M7 Workload → M8 Performance → M9 Reliability → M10 DR → M11 Portfolio.
