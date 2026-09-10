# DATA — M0 Baseline amended by ADR-001, ADR-002, and ADR-003

Status: FROZEN EXCEPT AS AMENDED BY ACCEPTED ADRS

## PostgreSQL responsibilities

PostgreSQL is the system of record for structured business and account state. Logical tables include users, programs, applications, attachment metadata, application status history, audit events, and Spring Session tables. Additional read models or review-comment tables are introduced only when an implemented workflow requires them.

All schema changes are managed by Flyway.

## M5 user/account fields

The M1 `users` table stores only `id`, `username`, `password_hash`, and `role`. ADR-002 approves a small additive expansion so applicant self-registration and browser identity can be represented explicitly.

User should include at least:

- `id`;
- unique `username` used as the login ID;
- `password_hash`;
- `display_name`;
- synthetic `email`/contact address with uniqueness enforced for registered identities;
- `role` (`APPLICANT`, `REVIEWER`, `ADMIN`);
- `created_at`;
- `updated_at`.

Existing synthetic bootstrap users are backfilled with deterministic synthetic display/contact values during the Flyway migration. No plaintext password or real personal data is introduced.

Public registration creates `APPLICANT` only. Reviewer/admin role assignment remains outside public registration and is supplied by the controlled bootstrap/operations path.

M5 does not add an account-status state machine, invitation-token table, external-identity table, organization-membership graph, password-reset token table, or MFA tables without a concrete implemented requirement.

## M5 structured business fields

The M1 MVP intentionally started with minimal program/application fields. ADR-001 and the M5 product-surface plan approve a small additive enrichment so the browser/API contract represents an identifiable support-program workflow.

Program should include at least:

- stable unique program code;
- title;
- description;
- publication status (`DRAFT`, `PUBLISHED`);
- application-open timestamp;
- application-close timestamp;
- optimistic-lock version;
- created/updated timestamps.

Application should include at least:

- program and applicant references;
- optional assigned reviewer;
- applicant organization name;
- project title;
- short summary;
- requested amount;
- detailed plan/content;
- current status;
- optimistic-lock version;
- created/updated timestamps.

All sample values remain synthetic. Do not add real personal, company, or financial data.

## Program lifecycle and admission

`DRAFT` and `PUBLISHED` are the only persisted program lifecycle states in M5.

Applicant-facing scheduled/open/closed intake state is derived from `publication_status`, `application_open_at`, `application_close_at`, and the server clock. Do not persist a second intake status that can drift from the timestamps.

The application window must satisfy `application_open_at < application_close_at`. A new application may be created only when the program is published and `application_open_at <= now < application_close_at`.

Draft programs may be edited. Publication is one-way for M5; ordinary commands do not unpublish or mutate an already published program. Program code is immutable.

Revision/resubmission of an existing application remains allowed after the intake window closes when the application is in the existing `NEEDS_REVISION` workflow, because it is not a new intake.

## Audit subjects

The M2 audit schema is application-specific because `application_id` is mandatory. M5 now has legitimate user and program events, so the schema is generalized while preserving foreign-key integrity.

An audit row has:

- non-null `actor_id`;
- nullable `application_id`;
- nullable `program_id`;
- nullable `subject_user_id`;
- event type and occurrence timestamp.

A database check constraint requires exactly one of the three subject references to be non-null.

Existing audit rows remain application-target events. M5 adds at least `USER_REGISTERED`, `PROGRAM_CREATED`, `PROGRAM_UPDATED`, and `PROGRAM_PUBLISHED`.

Do not replace explicit subject foreign keys with an untyped polymorphic ID while the known subject set remains small.

## Migration policy

Prefer additive / expand-contract evolution: `ADD → BACKFILL → TRANSITION → REMOVE later`. Avoid destructive schema changes that make application rollback immediately impossible.

M5 should prefer adding/backfilling user/program/application columns and generalized audit subject columns while temporarily retaining compatibility with the previous minimal representation until the API/SPA transition is verified. Existing synthetic programs are backfilled as published with deterministic non-expiring verification windows. Any later removal/rename occurs in a separate migration after compatibility is established.

Registration-related database constraints and application validation must agree on username/email uniqueness. API conflict handling must not rely solely on a pre-insert existence check; database uniqueness remains the final concurrency-safe constraint.

## Concurrency

`applications.version` supports optimistic locking so concurrent review decisions or edits cannot silently overwrite each other.

`programs.version` protects concurrent administrator edits before publication. Stale draft edits fail as conflicts rather than silently overwriting newer program configuration.

The REST API must surface stale writes as an explicit conflict. A client-observed version is part of the edit command contract; frontend state never bypasses server-side optimistic locking.

## Attachments

PostgreSQL stores metadata; Garage stores binary objects. Metadata includes at least: `id`, `application_id`, `object_key`, `original_filename`, `content_type`, `size_bytes`, `sha256`, `status`, `uploaded_by`, `created_at`.

Attachment states: `PENDING`, `AVAILABLE`, `FAILED`, `DELETE_PENDING`.

Upload sequence: create `PENDING` metadata → stream object to Garage → verify existence/size/hash → mark `AVAILABLE`. A scheduled reconciliation process detects stale pending objects, available metadata with missing objects, pending deletion, and unexpected inconsistencies. No distributed transaction or queue is introduced solely to make PostgreSQL and Garage atomic.

The browser never supplies authoritative object keys, hashes, owner IDs, or attachment status values.

## API data boundary

JPA entities are persistence/domain implementation details and are not serialized directly to browser clients. API request/response DTOs define the external contract and expose only required fields.

Registration responses never include `password_hash`. Role in registration responses is server-assigned. The registration request does not expose a role field that can be trusted or promoted by the server.

Large list endpoints use explicit pagination/filtering contracts. API compatibility should be preserved across a frontend/backend rollout using additive changes where practical.

## Performance policy

Primary/foreign/unique/integrity indexes may exist from the start. Do not add speculative composite performance indexes before measurement. Later analysis follows: k6/Grafana/trace → `pg_stat_statements` → target SQL → `EXPLAIN (ANALYZE, BUFFERS)` → change → same-data/same-workload remeasurement.
