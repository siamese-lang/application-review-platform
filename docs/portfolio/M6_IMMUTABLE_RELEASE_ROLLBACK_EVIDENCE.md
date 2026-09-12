# Evidence Card — Exact immutable release and schema-compatible rollback

Status: DRAFT  
Milestone: M6  
Evidence maturity: E3  
Source release SHA: `a26193598d0fbcb5a2f6d468739b36b7aef3f0aa`

## Context / assumption

The project runs a paired React static frontend and Spring Boot backend on separate GCP VMs. The earlier M4 deployment path could configure the runtime, but building/deploying from a working tree did not establish a durable proof that both runtime components came from one reviewed revision or that a known previous release could be restored exactly.

## Problem

Before M6, exact redeployment and rollback were not independently demonstrated. There was no retained paired release identity, immutable registry digest, versioned active/previous runtime state, or live rollback result that could prove which reviewed revision was running after a deployment or recovery action.

## Baseline

Environment:

- frozen seven-role GCP IaaS topology in `asia-northeast3`;
- Nginx public HTTPS edge, Spring Boot app VM, PostgreSQL single primary, three-node Garage, controlled `ops-01`;
- GitHub OIDC/WIF, IAP, and OS Login delivery path;
- synthetic users/data only.

Release A:

- SHA `53f5796235114481c62d9d178e395738f486ea3e`;
- OCI digest `sha256:0f3ec84718f001439b1cab365cfe8dc5f18246395f0dd0d3b71bb8d1398a49f9`.

Release B:

- SHA `a26193598d0fbcb5a2f6d468739b36b7aef3f0aa`;
- OCI digest `sha256:63716c0ff1b679ef2293fe1be47183828c87f323d13d2842bb8e8e84d280345c`;
- exact-release handoff workflow run `34695033956`.

The live database was at Flyway V5 with zero failed migrations. Release A and B had no intervening Flyway/schema change, establishing the rollback pair as schema compatible.

## Analysis

The missing evidence was not another deployment technology. It was identity and reversibility across the existing runtime boundary.

The implementation therefore focused on evidence that can be independently checked:

- full-SHA release manifests;
- backend/frontend SHA-256 payload checksums;
- immutable GHCR digest resolution and pull-back verification;
- exact-SHA retained installation;
- explicit current/previous release-state metadata;
- fail-closed rollback to the recorded previous release only;
- public business smoke before and after rollback.

## Options considered

1. Keep building/deploying from the operations working tree.
   - Rejected because the deployed backend/frontend pair could not be tied strongly enough to one reviewed immutable revision.

2. Containerize the application merely to use GHCR.
   - Rejected because it would change the frozen VM/JAR/static-frontend runtime without solving a requirement that needed containers.

3. Add destructive/down database migrations to make rollback automatic.
   - Rejected because application-binary rollback and database rollback have different compatibility risks. M6 keeps Flyway forward migrations and requires an explicit schema-compatibility acknowledgement.

4. Retain the VM runtime but publish one exact-SHA OCI release bundle and install versioned backend/frontend payloads.
   - Accepted as the smallest change that established immutable identity and an executable rollback path.

## Decision / action

M6 introduced a deterministic release contract containing the backend JAR, frontend archive, manifest, source SHA, sizes, and payload checksums; retained it in GHCR by full SHA/digest; used repository/workflow-constrained WIF for explicit handoff to `ops-01`; installed both components under versioned release paths; recorded current/previous identities; and implemented schema-compatible rollback without database down-migration.

## Verification

Release B was activated with both backend and frontend reporting B as current and A as previous. The full deployed HTTPS/API/Garage business smoke passed.

A real B → A rollback then completed successfully.

Observed rollback command-to-readiness elapsed time:

- **38,346 ms (38.346 s)**.

After rollback:

- backend/frontend both reported A as current and B as previous;
- no database migration rollback was performed;
- the full HTTPS/API/Garage smoke passed, including attachment SHA-256 integrity and final application history.

Release B was then reactivated, both components again reported B as current and A as previous, and the full smoke passed a final time.

## Trade-off / limit

The 38.346-second value is one observed drill result, not an SLA.

Rollback is permitted only when the operator has established schema compatibility. The mechanism deliberately does not undo Flyway migrations. A future incompatible schema/application pair must block binary rollback or use a separately designed forward-repair/recovery procedure.

This evidence proves controlled release identity and one real rollback drill in the project environment. It does not establish production availability, multi-region recovery, automatic failover, backup/PITR recovery, or performance under representative load.

## Repository evidence

- code/config:
  - `scripts/release/build-release-bundle.sh`
  - `scripts/release/verify-release-bundle.sh`
  - `deploy/deploy-release.sh`
  - `deploy/rollback-release.sh`
  - `scripts/deploy/release-mechanics.py`
  - `config/ansible/release.yml`
  - `config/ansible/rollback.yml`
  - `.github/workflows/deploy-release.yml`
- migration:
  - Flyway schema history through V5; failed migration count 0 during the Phase 5 run
- focused tests:
  - M6 release bundle/install/runtime/delivery workflow contract jobs in baseline CI
- workload/experiment:
  - real Release B → Release A schema-compatible rollback drill on 2026-09-12
- CI:
  - Release A publication run `34684066677`
  - Release B publication run `34692775057`
  - Release B exact handoff run `34695033956`
- runtime/query-plan/log evidence:
  - `docs/operations/M6_PHASE5_RELEASE_ROLLBACK_EVIDENCE.md`

## Portfolio claim

Built and verified an exact-SHA release path that paired backend and frontend artifacts, executed a schema-compatible rollback in 38.346 seconds without database down-migration, revalidated the full HTTPS/application/attachment flow, and returned the environment to the intended release.
