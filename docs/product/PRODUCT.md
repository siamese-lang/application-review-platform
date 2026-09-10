# PRODUCT — M0 Baseline amended by ADR-001

Status: FROZEN EXCEPT AS AMENDED BY ACCEPTED ADRS  
Baseline date: 2026-09-09  
Web-boundary amendment: 2026-09-11

## Product definition

A personal production-like support-program application, review, and operations platform. Individuals or synthetic organizations browse support programs, prepare and submit applications and evidence files, and track processing status. Reviewers work a submission queue, inspect application content/evidence, request revision, approve, or reject. Administrators have read-oriented operational visibility.

The finished system is deployed on GCP IaaS and exercised with realistic synthetic data, API/browser workflows, load, faults, backup, and recovery tests.

## Goals

- Implement a recognizable support-program application/review workflow rather than a generic CRUD demonstration.
- Preserve authorization, state-transition, audit, attachment, and recovery integrity.
- Expose a deliberate versioned HTTP API rather than coupling the final browser client directly to persistence entities.
- Provide a credible browser product surface for applicant, reviewer, and administrator workflows.
- Demonstrate browser security, frontend/backend delivery boundaries, reverse-proxy routing, and rollback concerns without adding unjustified distributed-system complexity.
- Produce reproducible performance and reliability evidence rather than invented operational claims.
- Separate browser, application, database, object storage, observability, operations, and verification concerns sufficiently to make failures diagnosable.

## Roles

### APPLICANT
Browse programs; inspect application windows; create, edit, and save own applications; upload/delete attachments when allowed; submit; revise after a supplement request; resubmit; view progress/history/results.

### REVIEWER
List/filter submitted work; view application and attachment details; start review; request revision; approve; reject; view status history.

### ADMIN
Operational read visibility into users, applications, workflow counts, histories, and audit information. A broad enterprise administration suite is out of scope.

## Minimum business information after M5

The system remains intentionally smaller than a government production platform, but the core records must carry enough structured information to support recognizable workflows.

Program includes a stable program code, title, description, and application window.

Application includes applicant organization name, project title, short summary, requested amount, detailed plan/content, attachments, current status, reviewer, version, timestamps, and status history.

All organizations, people, amounts, documents, and workloads are synthetic.

## Browser/API product boundary

`ADR-001-web-api-spa.md` changes the final browser surface from Thymeleaf to a React + TypeScript SPA backed by a Spring Boot REST API.

The production browser and API share one HTTPS origin through Nginx. Session authentication and Spring Session JDBC remain. REST/API and SPA are presentation/application boundaries; business transition rules remain in the domain/service layer.

## Milestones

Completed milestones retain their original identities:

- M0 Design — frozen baseline
- M1 Business MVP — login, program read, application create/edit/submit, reviewer start/revision/approve/reject, status history
- M2 Data Integrity — authorization, transactions, optimistic locking, history, audit, JDBC session
- M3 Attachment — Garage, metadata/object consistency, reconciliation
- M4 Cloud Deployment — GCP split roles, network, OpenTofu/Ansible, ops bootstrap, real HTTPS business/attachment verification

Future milestones are rebaselined after ADR-001:

- M5 Web/API & Product Surface — structured support-program fields, versioned REST API, SPA, session/CSRF behavior, browser E2E, Nginx routing contract
- M6 Operations & Delivery — CI/CD, frontend/backend artifact promotion, migration/deployment order, rollback, backup basics, verified GCP delivery
- M7 Observability — metrics, logs, traces, alerts across edge/API/data paths
- M8 Workload — synthetic datasets and k6 targeting the final API/browser boundary
- M9 Performance — measured bottleneck, change, same-condition remeasurement
- M10 Reliability — fixed fault scenarios R1–R5
- M11 DR — rebuild a new environment and measure recovery
- M12 Portfolio — architecture, evidence, screenshots/diagrams, and final README

## Claim boundary

This project must not claim real customers, production traffic, contractual SLA/SLO, enterprise HA, or measured values that were not actually produced and retained as evidence.

A polished SPA does not itself prove operational maturity; operational claims remain tied to later deployment, measurement, failure, and recovery evidence.
