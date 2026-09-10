# DATA — M0 Frozen Baseline

Status: FROZEN

## PostgreSQL responsibilities

PostgreSQL is the system of record for structured business state. Planned logical tables include users, programs, applications, attachment metadata, application status history, review comments, audit events, and Spring Session tables.

All schema changes are managed by Flyway.

## Migration policy

Prefer additive / expand-contract evolution: `ADD → BACKFILL → TRANSITION → REMOVE later`. Avoid destructive schema changes that make application rollback immediately impossible.

## Concurrency

`applications.version` supports optimistic locking so concurrent review decisions cannot silently overwrite each other.

## Attachments

PostgreSQL stores metadata; Garage stores binary objects. Metadata includes at least: `id`, `application_id`, `object_key`, `original_filename`, `content_type`, `size_bytes`, `sha256`, `status`, `uploaded_by`, `created_at`.

Attachment states: `PENDING`, `AVAILABLE`, `FAILED`, `DELETE_PENDING`.

Upload sequence: create `PENDING` metadata → stream object to Garage → verify existence/size/hash → mark `AVAILABLE`. A scheduled reconciliation process detects stale pending objects, available metadata with missing objects, pending deletion, and unexpected inconsistencies. No distributed transaction or queue is introduced solely to make PostgreSQL and Garage atomic.

## Performance policy

Primary/foreign/unique/integrity indexes may exist from the start. Do not add speculative composite performance indexes before measurement. Later analysis follows: k6/Grafana/trace → `pg_stat_statements` → target SQL → `EXPLAIN (ANALYZE, BUFFERS)` → change → same-data/same-workload remeasurement.
