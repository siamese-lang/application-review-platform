# AGENTS.md

## Purpose

This repository is the source of truth for the Application Review Platform. Read the M0 documents before changing implementation or infrastructure.

## Required reading

1. `docs/product/PRODUCT.md`
2. `docs/domain/DOMAIN.md`
3. `docs/architecture/ARCHITECTURE.md`
4. `docs/security/SECURITY.md`
5. `docs/data/DATA.md`
6. `docs/operations/BACKUP_RECOVERY.md`
7. `docs/workload/WORKLOAD.md`
8. `docs/NON_GOALS.md`
9. `docs/FREEZE_RECORD.md`

## Working rules

- Work only on the current milestone unless the task explicitly changes it.
- M0 architecture is frozen. Do not silently rewrite documentation to fit an implementation shortcut.
- Do not add Redis, Kafka, RabbitMQ, Kubernetes, Keycloak, Elasticsearch, another primary datastore, queue, cache, object store, or managed cloud application service without an approved ADR.
- Business rules and state transitions belong in domain/service code, not controllers or templates.
- Database schema changes must use Flyway.
- Measure before optimizing. Performance changes require evidence and same-condition remeasurement.
- Do not delete, weaken, or disable failing tests merely to finish a task.
- Never commit secrets, credentials, private keys, tokens, or real personal data. Do not place secrets in prompts, logs, README files, images, or container images.
- Prefer the simplest implementation that satisfies the frozen requirements and that the project owner can explain.

## Planning rule

For changes spanning multiple components or at least three major files, create a short plan under `docs/plans/active/` before implementation. Include Goal, Files/Components, Constraints, and Verification. Move it to `docs/plans/completed/` when done.

## ADR rule

Propose an ADR before implementing a change that adds or replaces a database, cache, queue, object-storage product, authentication system, microservice boundary, Kubernetes, managed cloud application service, database failover architecture, or backup architecture.

Bug fixes, tests, measured indexes, dashboards/metrics, patch updates, timeout tuning, and VM-size experiments do not require an ADR unless they alter a frozen architectural boundary.

## Definition of done

A task is done only when its requirements are met, relevant tests pass, existing behavior has not regressed, required migrations are present, no secrets are introduced, and no out-of-scope architecture changes were made.
