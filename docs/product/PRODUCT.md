# PRODUCT — M0 Frozen Baseline

Status: FROZEN  
Baseline date: 2026-09-09

## Product definition

A personal production-like application review and operations platform. Individuals or companies submit applications and evidence files for support programs. Reviewers examine submissions and request revision, approve, or reject them. The finished system will be deployed on GCP IaaS and exercised with realistic synthetic data, load, faults, backup, and recovery tests.

## Goals

- Implement a coherent business workflow before infrastructure experiments.
- Preserve authorization, state-transition, audit, attachment, and recovery integrity.
- Produce reproducible performance and reliability evidence rather than invented operational claims.
- Separate application, database, object storage, observability, operations, and verification concerns sufficiently to make failures diagnosable.

## Roles

### APPLICANT
Browse programs; create, edit, and save own applications; upload/delete attachments when allowed; submit; revise after a supplement request; resubmit; view results.

### REVIEWER
List submitted applications; view details; start review; request revision; approve; reject; view history.

### ADMIN
Operational read visibility into users, applications, histories, and audit information. A broad enterprise administration suite is out of scope.

## Milestones

- M0 Design — frozen baseline
- M1 Business MVP — login, program read, application create/edit/submit, reviewer start/revision/approve/reject, status history
- M2 Data Integrity — authorization, transactions, optimistic locking, history, audit, JDBC session
- M3 Attachment — Garage, metadata/object consistency, reconciliation
- M4 Cloud Deployment — GCP split roles, network, OpenTofu/Ansible, ops bootstrap
- M5 Operations — CI/CD, migration/rollback, backup basics
- M6 Observability — metrics, logs, traces, alerts
- M7 Workload — synthetic datasets and k6
- M8 Performance — measured bottleneck, change, same-condition remeasurement
- M9 Reliability — fixed fault scenarios R1–R5
- M10 DR — rebuild a new environment and measure recovery
- M11 Portfolio — architecture, evidence, and final README

## Claim boundary

This project must not claim real customers, production traffic, contractual SLA/SLO, enterprise HA, or measured values that were not actually produced and retained as evidence.
