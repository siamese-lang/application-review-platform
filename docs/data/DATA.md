# DATA — M0 Baseline amended by ADR-001

Status: FROZEN EXCEPT AS AMENDED BY ACCEPTED ADRS

## PostgreSQL responsibilities

PostgreSQL is the system of record for structured business state. Logical tables include users, programs, applications, attachment metadata, application status history, audit events, and Spring Session tables. Additional read models or review-comment tables are introduced only when an implemented workflow requires them.

All schema changes are managed by Flyway.

## M5 structured business fields

The M1 MVP intentionally started with minimal program/application fields. ADR-001 and the M5 product-surface plan approve a small additive enrichment so the browser/API contract represents an identifiable support-program workflow.

Program should include at least:

- stable program code;
- title;
- description;
- application-open timestamp;
- application-close timestamp.

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

## Migration policy

Prefer additive / expand-contract evolution: `ADD → BACKFILL → TRANSITION → REMOVE later`. Avoid destructive schema changes that make application rollback immediately impossible.

M5 should prefer adding/backfilling structured columns while temporarily retaining compatibility with the previous `title`/`content` representation until the API/SPA transition is verified. Any later removal/rename occurs in a separate migration after compatibility is established.

## Concurrency

`applications.version` supports optimistic locking so concurrent review decisions or edits cannot silently overwrite each other.

The REST API must surface stale writes as an explicit conflict. A client-observed version is part of the edit command contract; frontend state never bypasses server-side optimistic locking.

## Attachments

PostgreSQL stores metadata; Garage stores binary objects. Metadata includes at least: `id`, `application_id`, `object_key`, `original_filename`, `content_type`, `size_bytes`, `sha256`, `status`, `uploaded_by`, `created_at`.

Attachment states: `PENDING`, `AVAILABLE`, `FAILED`, `DELETE_PENDING`.

Upload sequence: create `PENDING` metadata → stream object to Garage → verify existence/size/hash → mark `AVAILABLE`. A scheduled reconciliation process detects stale pending objects, available metadata with missing objects, pending deletion, and unexpected inconsistencies. No distributed transaction or queue is introduced solely to make PostgreSQL and Garage atomic.

The browser never supplies authoritative object keys, hashes, owner IDs, or attachment status values.

## API data boundary

JPA entities are persistence/domain implementation details and are not serialized directly to browser clients. API request/response DTOs define the external contract and expose only required fields.

Large list endpoints use explicit pagination/filtering contracts. API compatibility should be preserved across a frontend/backend rollout using additive changes where practical.

## Performance policy

Primary/foreign/unique/integrity indexes may exist from the start. Do not add speculative composite performance indexes before measurement. Later analysis follows: k6/Grafana/trace → `pg_stat_statements` → target SQL → `EXPLAIN (ANALYZE, BUFFERS)` → change → same-data/same-workload remeasurement.
