# ADR-003 — Define program publication, intake window, and audit targets

Status: ACCEPTED

Decision date: 2026-09-11

## Context

M1–M4 treated support programs as seeded reference data. That was enough to verify application state transitions, authorization, attachments, and cloud deployment, but it leaves an obvious business gap for the finished system: there is no actor or workflow that creates a program, publishes it to prospective applicants, or enforces whether applications are currently being accepted.

M5 turns the minimal backend into a recognizable support-program application/review system. Program lifecycle rules must therefore be explicit before the REST API and SPA are implemented.

The existing application review model already uses a pull-based reviewer queue: an unassigned submitted application is claimed by the reviewer who starts review. This is a deliberate and sufficient assignment model for the current project; a separate reviewer-allocation subsystem is not required.

The existing `audit_events` table is application-specific because `application_id` is mandatory. ADR-002 introduced applicant self-registration and this ADR introduces administrator program lifecycle events, so the audit target model must also be generalized rather than pretending those events are application events.

## Decision

### Program ownership

`ADMIN` owns support-program setup.

M5 adds administrator commands to:

- create a program as `DRAFT`;
- edit a draft program;
- publish a valid draft program.

There is no public endpoint for creating or modifying programs.

### Program lifecycle

Persist only the lifecycle state that is authoritative and not derivable:

- `DRAFT` — visible only to administrators and not open to applicant submission;
- `PUBLISHED` — publicly discoverable.

Do not persist separate `SCHEDULED`, `OPEN`, or `CLOSED` states. Applicant-facing intake state is derived from publication state and the application window:

- `PUBLISHED` and current time before `application_open_at` → scheduled;
- `PUBLISHED` and `application_open_at <= now < application_close_at` → accepting applications;
- `PUBLISHED` and current time at/after `application_close_at` → closed.

This avoids duplicate state that can contradict timestamps.

### Program data

M5 expands `programs` to include at least:

- stable unique `code`;
- `title`;
- `description`;
- `publication_status` (`DRAFT`, `PUBLISHED`);
- `application_open_at`;
- `application_close_at`;
- optimistic-lock `version`;
- `created_at`;
- `updated_at`.

The application window must satisfy `application_open_at < application_close_at`.

Program code is immutable after creation. A draft may be edited before publication.

For M5, publication is one-way. A published program is not silently unpublished or rewritten through the ordinary edit command. Production amendment/republication workflows are legitimate future requirements but are out of scope until there is a concrete need.

### Application admission rule

Creating a new application is allowed only when the referenced program is `PUBLISHED` and the server clock is inside the application window.

This rule belongs in the service/domain layer and is enforced regardless of whether the SPA displays an Apply button.

An applicant may continue to view an existing application after the window closes. Closing the intake window prevents new applications; it does not retroactively change existing application status.

The existing revision/resubmission workflow remains valid after a revision request even if the original program intake window has closed. A reviewer-requested revision is part of an already accepted application, not a new intake.

### Reviewer assignment

Keep the existing pull-based claim-on-start model.

A `SUBMITTED` application with no reviewer may appear in the reviewer work queue. The reviewer who successfully starts review becomes its assigned reviewer. After assignment, only that reviewer may continue the review decision workflow.

Do not add administrator reviewer assignment, reassignment, reviewer groups, scoring panels, or multi-reviewer consensus in M5.

Concurrent attempts to claim the same submission must not result in two effective owners; the existing optimistic-lock/transaction boundary must surface the losing attempt as a conflict.

### Audit target generalization

The current audit table requires an application target. M5 generalizes it so one audit event has exactly one business subject:

- application;
- program;
- user.

Keep `actor_id` as the user that caused the event.

Add nullable subject foreign keys such as:

- existing `application_id`;
- `program_id`;
- `subject_user_id`.

A database check constraint must require exactly one subject reference to be non-null.

Existing application audit rows remain application-target events.

M5 adds at least:

- `USER_REGISTERED`;
- `PROGRAM_CREATED`;
- `PROGRAM_UPDATED`;
- `PROGRAM_PUBLISHED`.

For self-registration, the newly created applicant is both actor and user subject after persistence. Passwords, credentials, session identifiers, and request bodies are never audit payloads.

Do not introduce an untyped polymorphic `subject_type + subject_id` pair when explicit foreign keys can preserve referential integrity for the three known subject types.

## Migration

All changes use Flyway.

Prefer additive/expand-contract migration:

1. add program lifecycle/business columns and deterministic backfill for existing synthetic programs;
2. add audit subject columns and temporarily relax the existing application-only constraint;
3. backfill/retain existing audit rows as application-target events;
4. add the exactly-one-subject check constraint;
5. update application code to the generalized audit representation;
6. remove compatibility-only assumptions only after the new path is verified.

Existing seeded programs must remain usable for regression tests. Backfill them as published synthetic programs with deterministic application windows broad enough not to expire during normal project verification.

## Consequences

Positive:

- the system has a complete program setup → publication → public discovery → application intake boundary;
- applicants cannot submit to unpublished or closed programs merely by calling the API directly;
- intake state cannot drift from timestamps because open/closed is derived;
- reviewer assignment remains simple and defensible rather than growing into a separate scheduling product;
- user, program, and application actions can share one referentially constrained audit mechanism.

Trade-offs:

- published programs are immutable in M5, so post-publication correction/amendment is intentionally unavailable;
- reviewer reassignment is intentionally unavailable;
- the audit table gains nullable subject foreign keys plus an exactly-one-subject constraint.

These are explicit scope choices, not claims of full government-grant administration functionality.

## Verification requirements

M5 must verify at least:

1. only an administrator can create/edit/publish a program;
2. a new program starts as `DRAFT` and is not visible through the public program API;
3. publication fails when the application window is invalid;
4. a published program is publicly readable;
5. derived intake state is scheduled/open/closed according to server time and the stored window;
6. application creation succeeds only for an open published program;
7. direct API calls cannot create an application for a draft, scheduled, or closed program;
8. revision/resubmission remains possible for an already accepted application after intake closes when the workflow is in `NEEDS_REVISION`;
9. draft program edits use optimistic locking and stale updates fail as conflicts;
10. published program mutation/unpublish is rejected by the ordinary M5 commands;
11. reviewer claim-on-start remains exclusive under concurrent claims;
12. audit rows enforce exactly one subject and retain referential integrity;
13. registration and program lifecycle events create the approved non-secret audit types;
14. existing application audit behavior remains green.
