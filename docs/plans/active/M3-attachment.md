# M3 Attachment — Execution Plan

Status: ACTIVE

## Goal

Add evidence-file attachment handling to the completed M2 application workflow using PostgreSQL for attachment metadata and Garage for binary objects, while preserving ownership/state authorization and making cross-store inconsistencies detectable and recoverable through explicit attachment lifecycle states and reconciliation.

M3 implements attachment correctness only. It does not begin GCP deployment, multi-node Garage reliability testing, backup/DR, observability, workload generation, or performance tuning.

## Baseline and confirmed gaps

M2 already provides session-based authentication, actor-aware application reads, ownership/role enforcement, optimistic locking, status history, audit events, and PostgreSQL-backed Spring Session.

The M3 gaps confirmed on `main` are:

- no attachment metadata table, entity, repository, service, controller, or templates exist;
- no Garage/S3 client configuration or storage adapter exists;
- no attachment lifecycle states (`PENDING`, `AVAILABLE`, `FAILED`, `DELETE_PENDING`) are implemented;
- no reconciliation process exists for stale/inconsistent DB/object state;
- current CI verifies PostgreSQL-backed application behavior but does not exercise Garage.

## Frozen M0 boundaries

- PostgreSQL is the system of record for structured attachment metadata.
- Garage is the primary binary object store and is accessed through its S3-compatible API.
- Attachment metadata includes at least: `id`, `application_id`, `object_key`, `original_filename`, `content_type`, `size_bytes`, `sha256`, `status`, `uploaded_by`, `created_at`.
- Attachment states are `PENDING`, `AVAILABLE`, `FAILED`, `DELETE_PENDING`.
- Attachments are mutable only while the parent application is `DRAFT` or `NEEDS_REVISION`.
- No distributed transaction, queue, second primary object store, or managed cloud storage service is introduced to make PostgreSQL and Garage atomic.
- Development/CI may use one Garage node with replication 1. The final three-node Garage topology and storage fault testing remain later-milestone work.

## Scope

### 1. Attachment metadata and domain lifecycle

Add an additive Flyway migration after the existing V1–V3 migrations. Do not modify shipped migrations.

The attachment table must contain the frozen minimum metadata and enforce useful relational integrity such as:

- foreign keys to the parent application and uploading user;
- unique server-generated `object_key`;
- explicit attachment status values;
- non-negative size;
- `AVAILABLE` rows must have a SHA-256 value and complete metadata required for verified download.

Use a small attachment domain model with explicit lifecycle transitions rather than arbitrary status mutation. A version column / JPA optimistic locking should be used if needed to prevent stale upload-finalization, delete, and reconciliation operations from silently overwriting one another.

`object_key` is generated only by the server and must not be derived directly from the original filename. Original filenames are display/download metadata only.

### 2. Garage object-storage adapter

Keep S3/Garage calls behind a small application storage adapter/service; controllers must not call the S3 client directly.

Expected implementation is an S3-compatible Java client, with AWS SDK for Java v2 as the default practical choice unless current upstream Garage/client documentation shows a compatibility issue. Using the S3 client does not introduce an AWS cloud service; Garage remains the object store.

Configuration must support at least:

- Garage S3 endpoint;
- bucket;
- region value required by the client/Garage configuration;
- access key and secret key;
- path-style addressing or other Garage-compatible addressing when required.

No real credentials are committed. CI/test credentials are synthetic and generated or injected at runtime. Later production secret delivery remains the M4/M5 operations path.

### 3. Upload flow

Applicant upload is allowed only when:

- the authenticated actor owns the parent application; and
- the application status is `DRAFT` or `NEEDS_REVISION`.

Use the frozen cross-store sequence:

1. create and commit `PENDING` metadata before the object write;
2. stream the binary object to Garage without loading the whole file into application memory;
3. calculate the actual byte count and SHA-256 from the uploaded content;
4. verify the stored Garage object by reading/streaming it back and comparing size and SHA-256; do not treat an S3 ETag as a SHA-256 guarantee;
5. only after verification, transition the metadata to `AVAILABLE` in PostgreSQL.

Failure handling must distinguish explicit failure from process interruption:

- an explicit upload/storage/verification failure must never leave the row falsely `AVAILABLE`; mark it `FAILED` when the failure can be durably classified and perform safe best-effort object cleanup;
- if execution stops after the object write but before final DB transition, the durable `PENDING` row is intentionally left for reconciliation rather than inventing atomicity between the stores.

Do not hold a long PostgreSQL transaction open across the entire remote object upload merely to imitate a distributed transaction.

### 4. Read and download authorization

Only `AVAILABLE` attachments are downloadable through normal user flows.

- APPLICANT: may list/download attachments only for their own application.
- REVIEWER: may list/download attachments only when the existing reviewer visibility rules allow access to the parent application.
- ADMIN attachment-management functions are not required in M3; do not expand the admin surface without a separate requirement.

Downloads must use server-side authorization before resolving the object key. Do not expose a public Garage endpoint or accept an arbitrary object key from the browser as authority.

Use the stored original filename only for safe response metadata such as `Content-Disposition`; sanitize/encode it appropriately and do not use it as a filesystem/object path.

### 5. Delete flow

Applicant deletion is allowed only for the owner while the parent application is `DRAFT` or `NEEDS_REVISION`.

Use an explicit deletion lifecycle rather than deleting DB metadata first:

1. transition the attachment to `DELETE_PENDING` in PostgreSQL;
2. delete the corresponding Garage object idempotently;
3. confirm the object is absent;
4. remove/finalize the metadata only after object deletion is confirmed.

If object deletion fails or execution is interrupted, keep `DELETE_PENDING` so reconciliation can retry. Upload finalization must not be able to overwrite a concurrent delete request and return the row to `AVAILABLE`.

### 6. Reconciliation

Implement a deterministic reconciliation service that can be invoked directly by tests and wrapped by scheduled execution. The stale threshold and schedule should be configurable; tests must not depend on wall-clock waiting.

At minimum reconciliation must detect and handle:

- stale `PENDING` metadata with no object → transition to `FAILED`;
- stale `PENDING` metadata with a complete Garage object → recompute/verify size and SHA-256 and promote to `AVAILABLE` only when verification succeeds;
- `AVAILABLE` metadata whose object is missing or whose size/hash no longer matches → mark the metadata inconsistent/failed using the existing `FAILED` state rather than continuing to serve it;
- `DELETE_PENDING` → retry deletion and finalize metadata removal after confirmed absence;
- Garage objects under the project-managed attachment prefix that have no metadata reference → detect/report them as orphan objects. Do not automatically delete an unexpected orphan unless ownership and safety are deterministic.

Reconciliation must be idempotent: running it repeatedly against the same stable state must not create duplicate metadata or damage a valid object.

Do not add Kafka/RabbitMQ, distributed locks, or a compensating-transaction framework solely for reconciliation.

### 7. Web surface

Keep the existing Spring MVC/Thymeleaf application.

Applicant application detail should minimally support:

- attachment list;
- upload form only when the application is mutable;
- delete action only when mutation is allowed;
- clear status for non-`AVAILABLE` attachment records when useful for recovery/debugging without exposing internal credentials or storage details.

Reviewer application detail should allow authorized attachment list/download but no attachment mutation.

CSRF remains enabled for upload/delete POST requests.

### 8. Garage development and CI verification

M3 must be verified against a real Garage instance, not only a mocked S3 client.

For CI/dev verification use the frozen lightweight topology:

- one Garage node;
- replication factor 1;
- one synthetic test bucket and synthetic credentials;
- a pinned, explicitly recorded Garage version rather than an unbounded `latest` image/tag.

Add the smallest reproducible bootstrap/configuration needed for GitHub Actions. Use current official Garage documentation during implementation because bootstrap commands and container configuration are version-sensitive.

The project must not depend on the owner's weak local PC having Docker/Garage installed; GitHub Actions remains the authoritative integration environment when local execution is unavailable.

## Likely files / components

Implementation is expected to touch multiple components, including:

- `app/pom.xml` for the S3-compatible Java client;
- `app/src/main/resources/application.yml` and test configuration;
- a new Flyway migration such as `V4__m3_attachments.sql`;
- attachment domain entity/status and repository;
- attachment service/lifecycle/reconciliation components;
- Garage/S3 storage adapter and configuration properties;
- applicant/reviewer controllers and Thymeleaf templates where attachment UI is required;
- exception handling only where required for safe attachment responses;
- PostgreSQL + Garage integration/security/reconciliation tests;
- `.github/workflows/baseline-ci.yml` and a minimal Garage test bootstrap/config script if needed.

The exact file split may change as long as the frozen behavior and this M3 scope are preserved.

## Out of scope

Do not pull the following into M3:

- GCP VM/VPC/firewall/IAP/NAT provisioning or `ops-01` bootstrap (M4);
- final three-node Garage deployment or node-loss reliability experiments (M4/M9 as appropriate);
- CI/CD deployment automation, rollback automation, pgBackRest, or independent object backup implementation (M5+);
- Prometheus/Loki/Tempo/Grafana/Alertmanager/Alloy (M6);
- synthetic bulk datasets or k6 (M7);
- performance tuning, multipart/chunked/resumable upload optimization, CDN, or presigned-download optimization (M8+ or out of scope unless later justified);
- fault injection/storage reliability scenarios (M9);
- PITR/full DR/object-backup recovery exercises (M10);
- malware scanning as a required feature;
- Redis, Kafka, RabbitMQ, Kubernetes, Keycloak, Elasticsearch, another primary object store, or a managed application storage service;
- broad attachment administration, review comments, email/SMS workflows, or unrelated M2 redesign;
- automatic deletion of arbitrary unexpected Garage objects when ownership cannot be proven.

No ADR is expected because Garage is already the frozen primary object-storage product. If implementation proposes replacing Garage or adding another primary object store, stop and propose an ADR first.

## Verification

M3 is not complete unless all of the following are verified:

1. All M1/M2 workflow, security, concurrency, audit, and Spring Session tests continue to pass.
2. Flyway upgrades a clean PostgreSQL database through the new attachment migration and Hibernate schema validation succeeds.
3. Applicant ownership and `DRAFT` / `NEEDS_REVISION` rules reject unauthorized or immutable-state upload/delete attempts without attachment/object mutation.
4. Reviewer read/download access follows the existing reviewer visibility rules and cannot mutate attachments.
5. A real Garage integration test proves upload bytes reach Garage, metadata moves `PENDING → AVAILABLE`, stored size/SHA-256 match, and downloaded bytes match the original content.
6. `AVAILABLE` is never committed when Garage upload or verification fails.
7. A process-gap scenario can leave durable `PENDING`, and reconciliation resolves stale pending state deterministically.
8. Missing or corrupted/mismatched objects behind `AVAILABLE` metadata are detected and are no longer served as valid attachments.
9. Delete flow uses `DELETE_PENDING`, is retryable/idempotent, and does not remove the metadata before object absence is confirmed.
10. Concurrent/stale lifecycle updates cannot silently resurrect a deleting attachment or overwrite a newer attachment state.
11. Reconciliation is idempotent and detects managed-prefix orphan objects without unsafe automatic deletion.
12. Browser-supplied application/user/object identifiers do not bypass service-layer ownership/role checks; object keys are server-generated.
13. CSRF and existing login/route restrictions remain enabled and functional.
14. No credentials, binary fixtures containing real data, or sensitive request bodies are committed/logged.
15. GitHub Actions on the exact final PR head run PostgreSQL plus real single-node Garage integration and `./mvnw verify` successfully.
16. Repository-baseline CI remains green and no M4+ or unapproved architecture change appears in the diff.

## Execution workflow

After this plan is reviewed and merged to `main`:

1. Create a fresh M3 implementation branch from the then-current `main`.
2. Use Codex as the preferred workspace for the substantive multi-file implementation.
3. Codex must read `AGENTS.md`, `README.md`, `docs/WORKFLOW.md`, the relevant frozen M0 documents, this plan, and the completed M2 plan before editing.
4. Confirm the current Garage S3/bootstrap behavior and Java S3 client compatibility from current official upstream documentation before pinning implementation details.
5. Implement only M3 attachment behavior and the CI fixture required to verify it.
6. Open the M3 PR and inspect the actual diff rather than relying on the Codex summary.
7. Require GitHub Actions to pass on the exact final PR head. If CI fails, diagnose the first meaningful causal failure and apply the smallest direct correction.
8. Only after every M3 done condition is met, move this plan to `docs/plans/completed/`, update README to M3 complete/M4 next, rerun CI on the resulting final head, merge, and verify post-merge `main` CI.

## Done when

M3 is done only when attachment authorization, metadata lifecycle, real Garage object persistence and verification, delete semantics, and reconciliation are implemented and verified without weakening M1/M2 behavior; the final PR contains no M4+ scope; this plan is moved to completed; README reflects M3 completion; the exact final PR head passes required Actions; and the merged `main` workflow succeeds.
