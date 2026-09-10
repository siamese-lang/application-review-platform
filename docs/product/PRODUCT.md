# PRODUCT — M0 Baseline amended by ADR-001, ADR-002, and ADR-003

Status: FROZEN EXCEPT AS AMENDED BY ACCEPTED ADRS  
Baseline date: 2026-09-09  
Web-boundary amendment: 2026-09-11  
Account-lifecycle amendment: 2026-09-11  
Program-lifecycle amendment: 2026-09-11

## Product definition

A personal production-like support-program application, review, and operations platform. Prospective applicants can browse public support programs before authentication. Applicants register, sign in, prepare and submit applications and evidence files, and track processing status. Reviewers work a submission queue, claim submitted work, inspect application content/evidence, request revision, approve, or reject. Administrators create and publish support programs and retain operational visibility over users, applications, histories, and audits.

The finished system is deployed on GCP IaaS and exercised with realistic synthetic data, API/browser workflows, load, faults, backup, and recovery tests.

## Goals

- Implement a recognizable support-program application/review workflow rather than a generic CRUD demonstration.
- Preserve authorization, state-transition, audit, attachment, and recovery integrity.
- Expose a deliberate versioned HTTP API rather than coupling the final browser client directly to persistence entities.
- Provide a credible browser product surface for applicant, reviewer, and administrator workflows.
- Give external applicants a coherent public-discovery → registration → login → private-application journey.
- Keep reviewer/admin privilege assignment outside public self-registration.
- Model program setup and publication explicitly so application intake is controlled by server-side business rules rather than seeded data or UI visibility alone.
- Demonstrate browser security, frontend/backend delivery boundaries, reverse-proxy routing, and rollback concerns without adding unjustified distributed-system complexity.
- Produce reproducible performance and reliability evidence rather than invented operational claims.
- Separate browser, application, database, object storage, observability, operations, and verification concerns sufficiently to make failures diagnosable.

## Roles and account lifecycle

### APPLICANT

An external applicant may browse public program information without authentication and may self-register an applicant account.

After authentication, an applicant can create, edit, and save own applications; upload/delete attachments when allowed; submit; revise after a supplement request; resubmit; and view progress/history/results.

Public registration always creates `APPLICANT`. A registration request cannot select or grant another role.

### REVIEWER

Reviewer access is privileged because it exposes submissions owned by other users. Reviewers therefore do not self-register through the public browser/API.

For this synthetic project, reviewer accounts are provisioned through the controlled bootstrap/operations path. They use the same Spring Security/Spring Session authentication path after provisioning.

Reviewers can list/filter submitted work; view application and attachment details; start review; request revision; approve; reject; and view status history.

### ADMIN

Administrators also have no public self-registration path. Admin identities are controlled bootstrap/operations identities.

Administrators create draft support programs, edit drafts, and publish valid programs. They also have operational read visibility into users, applications, workflow counts, histories, and audit information. A broad enterprise IAM or administration suite is out of scope.

### Identity limitations

The project uses only synthetic identities and does not claim real-world identity proofing. Email verification, password-reset delivery, MFA/OTP, enterprise SSO/OIDC, and reviewer invitation delivery are not implemented in M5 because there is no real external identity or messaging provider to integrate with.

These are documented production gaps rather than simulated with fake integrations.

## Minimum business information after M5

The system remains intentionally smaller than a government production platform, but the core records must carry enough structured information to support recognizable workflows.

User includes a unique login ID, password hash, display name, synthetic email/contact field, role, and creation/update timestamps.

Program includes a stable program code, title, description, publication state, application window, optimistic-lock version, and creation/update timestamps. Public intake state is derived from publication state and the application window rather than stored as a second mutable status.

Application includes applicant organization name, project title, short summary, requested amount, detailed plan/content, attachments, current status, reviewer, version, timestamps, and status history.

All organizations, people, amounts, documents, and workloads are synthetic.

## Browser/API product boundary

`ADR-001-web-api-spa.md` changes the final browser surface from Thymeleaf to a React + TypeScript SPA backed by a Spring Boot REST API.

`ADR-002-account-lifecycle.md` defines public applicant registration, public program discovery, and controlled reviewer/admin provisioning.

`ADR-003-program-lifecycle.md` defines administrator program creation/publication, derived intake state, application admission rules, reviewer claim-on-start, and generalized audit subjects.

The production browser and API share one HTTPS origin through Nginx. Session authentication and Spring Session JDBC remain. REST/API and SPA are presentation/application boundaries; business transition rules remain in the domain/service layer.

## Milestones

Completed milestones retain their original identities:

- M0 Design — frozen baseline
- M1 Business MVP — login, program read, application create/edit/submit, reviewer start/revision/approve/reject, status history
- M2 Data Integrity — authorization, transactions, optimistic locking, history, audit, JDBC session
- M3 Attachment — Garage, metadata/object consistency, reconciliation
- M4 Cloud Deployment — GCP split roles, network, OpenTofu/Ansible, ops bootstrap, real HTTPS business/attachment verification

Future milestones are rebaselined after ADR-001/ADR-002/ADR-003:

- M5 Web/API & Product Surface — applicant registration, administrator program lifecycle, structured support-program/user/application fields, generalized audit subjects, versioned REST API, SPA, session/CSRF behavior, browser E2E, Nginx routing contract
- M6 Operations & Delivery — CI/CD, frontend/backend artifact promotion, migration/deployment order, rollback, backup basics, verified GCP delivery
- M7 Observability — metrics, logs, traces, alerts across edge/API/data paths
- M8 Workload — synthetic datasets and k6 targeting the final API/browser boundary
- M9 Performance — measured bottleneck, change, same-condition remeasurement
- M10 Reliability — fixed fault scenarios R1–R5
- M11 DR — rebuild a new environment and measure recovery
- M12 Portfolio — architecture, evidence, screenshots/diagrams, and final README

## Claim boundary

This project must not claim real customers, production traffic, contractual SLA/SLO, enterprise HA, verified external identities, or measured values that were not actually produced and retained as evidence.

A polished SPA or applicant signup screen does not itself prove operational maturity; operational claims remain tied to later deployment, measurement, failure, and recovery evidence.
