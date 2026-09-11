# AGENTS.md

## Purpose

This repository is the source of truth for the Application Review Platform. Read the current project status, workflow rules, and relevant M0 documents before changing implementation or infrastructure.

## Required reading

1. `README.md`
2. `docs/PROJECT_EXECUTION.md`
3. `docs/WORKFLOW.md`
4. `docs/product/PRODUCT.md`
5. `docs/domain/DOMAIN.md`
6. `docs/architecture/ARCHITECTURE.md`
7. `docs/security/SECURITY.md`
8. `docs/data/DATA.md`
9. `docs/operations/BACKUP_RECOVERY.md`
10. `docs/workload/WORKLOAD.md`
11. `docs/NON_GOALS.md`
12. `docs/FREEZE_RECORD.md`
13. The current plan under `docs/plans/active/`, when one exists

## Working rules

- Before changing anything, inspect the current intended base branch, active plan, relevant open PRs, and CI state. Do not infer repository state from chat history.
- Follow the tool responsibilities and branch/PR/CI flow in `docs/WORKFLOW.md`.
- Work only on the current milestone unless the task explicitly changes it.
- M0 architecture is frozen. Do not silently rewrite documentation to fit an implementation shortcut.
- Do not add Redis, Kafka, RabbitMQ, Kubernetes, Keycloak, Elasticsearch, another primary datastore, queue, cache, object store, or managed cloud application service without an approved ADR.
- Business rules and state transitions belong in domain/service code, not controllers or templates.
- Database schema changes must use Flyway.
- Measure before optimizing. Performance changes require evidence and same-condition remeasurement.
- Do not delete, weaken, or disable failing tests merely to finish a task.
- When CI fails, identify the first meaningful causal failure and compare it with the exact commit under test before changing code or configuration. Do not change several plausible causes at once.
- Never commit secrets, credentials, private keys, tokens, or real personal data. Do not place secrets in prompts, logs, README files, images, or container images.
- Prefer the simplest implementation that satisfies the frozen requirements and that the project owner can explain.
- Follow `docs/PROJECT_EXECUTION.md` for portfolio evidence goals, DB/SQL evidence requirements, tool division, and anti-drift rules.

## Planning rule

For changes spanning multiple components or at least three major files, create a short plan under `docs/plans/active/` before implementation. Include Goal, Files/Components, Constraints, and Verification. Move it to `docs/plans/completed/` when done.

## ADR rule

Propose an ADR before implementing a change that adds or replaces a database, cache, queue, object-storage product, authentication system, microservice boundary, Kubernetes, managed cloud application service, database failover architecture, or backup architecture.

Bug fixes, tests, measured indexes, dashboards/metrics, patch updates, timeout tuning, and VM-size experiments do not require an ADR unless they alter a frozen architectural boundary.

## Definition of done

A task is done only when its requirements are met, relevant tests pass, existing behavior has not regressed, required migrations are present, no secrets are introduced, no out-of-scope architecture changes were made, and the final PR head has passed the required GitHub Actions checks when applicable.
