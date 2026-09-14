#!/usr/bin/env python3
from __future__ import annotations

import csv
import hashlib
import json
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterable

NAMESPACE_MIN = 8_000_000_000
NAMESPACE_MAX = 8_999_999_999

PROGRAM_ID_BASE = 8_000_000_000
APPLICANT_ID_BASE = 8_100_000_000
REVIEWER_ID_BASE = 8_110_000_000
APPLICATION_ID_BASE = 8_200_000_000
HISTORY_ID_BASE = 8_300_000_000
AUDIT_ID_BASE = 8_400_000_000

BASE_TIME = datetime(2026, 1, 1, tzinfo=timezone.utc)

API_VERIFICATION_PAYLOAD = {
    "organization": "Synthetic Organization API",
    "projectTitle": "M8 API Verification Project",
    "shortSummary": "Deterministic M8 API verification payload",
    "requestedAmount": "1234567.00",
    "detailedPlan": "Deterministic M8 API verification detailed plan used only by integration tests.",
}


@dataclass(frozen=True)
class DatasetSpec:
    name: str
    applications: int
    applicants: int
    reviewers: int
    programs: int


@dataclass(frozen=True)
class Transition:
    source: str
    target: str
    actor: str
    audit_event: str
    reason: str | None = None


SUBMIT = Transition("DRAFT", "SUBMITTED", "applicant", "APPLICATION_SUBMITTED")
START = Transition("SUBMITTED", "IN_REVIEW", "reviewer", "REVIEW_STARTED")
REVISION = Transition(
    "IN_REVIEW",
    "NEEDS_REVISION",
    "reviewer",
    "REVISION_REQUESTED",
    "Synthetic revision requested",
)
RESUBMIT = Transition("NEEDS_REVISION", "SUBMITTED", "applicant", "APPLICATION_SUBMITTED")
APPROVE = Transition("IN_REVIEW", "APPROVED", "reviewer", "APPLICATION_APPROVED")
REJECT = Transition(
    "IN_REVIEW",
    "REJECTED",
    "reviewer",
    "APPLICATION_REJECTED",
    "Synthetic rejection reason",
)

# Twelve deterministic buckets. The full cycle contains 48 history rows, i.e. 4/application.
PATHS: tuple[tuple[Transition, ...], ...] = (
    (),
    (SUBMIT,),
    (SUBMIT, START),
    (SUBMIT, START, REVISION),
    (SUBMIT, START, APPROVE),
    (SUBMIT, START, REJECT),
    (SUBMIT, START, REVISION, RESUBMIT, START, APPROVE),
    (SUBMIT, START, REVISION, RESUBMIT, START, APPROVE),
    (SUBMIT, START, REVISION, RESUBMIT, START, APPROVE),
    (SUBMIT, START, REVISION, RESUBMIT, START, APPROVE),
    (SUBMIT, START, REVISION, RESUBMIT, START, REJECT),
    (SUBMIT, START, REVISION, RESUBMIT, START, REJECT),
)


def iso(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def mix(seed: int, index: int, salt: int) -> int:
    value = (seed & 0xFFFFFFFFFFFFFFFF) ^ ((index + 1) * 0x9E3779B97F4A7C15) ^ salt
    value &= 0xFFFFFFFFFFFFFFFF
    value ^= value >> 30
    value = (value * 0xBF58476D1CE4E5B9) & 0xFFFFFFFFFFFFFFFF
    value ^= value >> 27
    value = (value * 0x94D049BB133111EB) & 0xFFFFFFFFFFFFFFFF
    value ^= value >> 31
    return value & 0xFFFFFFFFFFFFFFFF


def load_profiles(path: Path) -> dict[str, DatasetSpec]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    return {
        name: DatasetSpec(
            name=name,
            applications=int(values["applications"]),
            applicants=int(values["applicants"]),
            reviewers=int(values["reviewers"]),
            programs=int(values["programs"]),
        )
        for name, values in raw.items()
    }


def history_count(application_count: int) -> int:
    cycles, remainder = divmod(application_count, len(PATHS))
    return cycles * sum(len(path) for path in PATHS) + sum(
        len(PATHS[i]) for i in range(remainder)
    )


def final_status(path: tuple[Transition, ...]) -> str:
    return path[-1].target if path else "DRAFT"


def write_csv(path: Path, header: list[str], rows: Iterable[list[object]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(header)
        writer.writerows(rows)


def program_rows(spec: DatasetSpec, seed: int) -> Iterable[list[object]]:
    created = iso(BASE_TIME - timedelta(days=365))
    open_at = iso(BASE_TIME - timedelta(days=30))
    close_at = iso(BASE_TIME + timedelta(days=730))
    for i in range(spec.programs):
        pid = PROGRAM_ID_BASE + i + 1
        code = f"M8-P{i + 1:03d}"
        yield [
            pid,
            f"M8 Synthetic Program {i + 1:03d}",
            f"Deterministic M8 program seed={seed} index={i + 1}",
            code,
            "PUBLISHED",
            open_at,
            close_at,
            0,
            created,
            created,
        ]


def user_rows(spec: DatasetSpec, seed: int) -> Iterable[list[object]]:
    created = iso(BASE_TIME - timedelta(days=90))
    for i in range(spec.applicants):
        uid = APPLICANT_ID_BASE + i + 1
        username = f"m8-applicant-{i + 1:05d}"
        yield [
            uid,
            username,
            "M8-NO-LOGIN",
            f"M8 Applicant {i + 1:05d}",
            f"{username}@example.test",
            "APPLICANT",
            created,
            created,
        ]
    for i in range(spec.reviewers):
        uid = REVIEWER_ID_BASE + i + 1
        username = f"m8-reviewer-{i + 1:04d}"
        yield [
            uid,
            username,
            "M8-NO-LOGIN",
            f"M8 Reviewer {i + 1:04d}",
            f"{username}@example.test",
            "REVIEWER",
            created,
            created,
        ]


def application_context(spec: DatasetSpec, seed: int, index: int) -> dict[str, object]:
    path = PATHS[index % len(PATHS)]
    applicant_slot = mix(seed, index, 0xA11CE) % spec.applicants
    reviewer_slot = mix(seed, index, 0xBEEF) % spec.reviewers
    program_slot = mix(seed, index, 0xC0DE) % spec.programs

    applicant_id = APPLICANT_ID_BASE + applicant_slot + 1
    reviewer_id = REVIEWER_ID_BASE + reviewer_slot + 1
    program_id = PROGRAM_ID_BASE + program_slot + 1
    application_id = APPLICATION_ID_BASE + index + 1

    created_at = BASE_TIME + timedelta(seconds=index * 30)
    updated_at = created_at + timedelta(minutes=len(path))
    requested_amount = 1_000_000 + (mix(seed, index, 0xD00D) % 9000) * 10_000

    project_title = f"M8 Project {index + 1:06d} seed-{seed}"
    detailed_plan = (
        f"Deterministic M8 detailed plan for application {index + 1:06d}; "
        f"seed={seed}; program={program_slot + 1:03d}."
    )

    return {
        "index": index,
        "path": path,
        "application_id": application_id,
        "program_id": program_id,
        "applicant_id": applicant_id,
        "reviewer_id": reviewer_id if len(path) >= 2 else None,
        "project_title": project_title,
        "detailed_plan": detailed_plan,
        "organization": f"Synthetic Organization {applicant_slot + 1:05d}",
        "short_summary": f"M8 synthetic application {index + 1:06d} for repeatable workload data.",
        "requested_amount": f"{requested_amount}.00",
        "status": final_status(path),
        "version": len(path),
        "created_at": created_at,
        "updated_at": updated_at,
    }


def application_rows(spec: DatasetSpec, seed: int) -> Iterable[list[object]]:
    for i in range(spec.applications):
        ctx = application_context(spec, seed, i)
        yield [
            ctx["application_id"],
            ctx["program_id"],
            ctx["applicant_id"],
            ctx["reviewer_id"] or "",
            ctx["project_title"],
            ctx["detailed_plan"],
            ctx["status"],
            iso(ctx["created_at"]),
            iso(ctx["updated_at"]),
            ctx["version"],
            ctx["organization"],
            ctx["project_title"],
            ctx["short_summary"],
            ctx["requested_amount"],
            ctx["detailed_plan"],
        ]


def history_rows(spec: DatasetSpec, seed: int) -> Iterable[list[object]]:
    hid = HISTORY_ID_BASE
    for i in range(spec.applications):
        ctx = application_context(spec, seed, i)
        for step, transition in enumerate(ctx["path"], start=1):
            hid += 1
            changed_by = (
                ctx["applicant_id"] if transition.actor == "applicant" else ctx["reviewer_id"]
            )
            yield [
                hid,
                ctx["application_id"],
                transition.source,
                transition.target,
                changed_by,
                iso(ctx["created_at"] + timedelta(minutes=step)),
                transition.reason or "",
            ]


def audit_rows(spec: DatasetSpec, seed: int) -> Iterable[list[object]]:
    aid = AUDIT_ID_BASE
    for i in range(spec.applications):
        ctx = application_context(spec, seed, i)
        aid += 1
        yield [
            aid,
            ctx["application_id"],
            "",
            "",
            ctx["applicant_id"],
            "APPLICATION_CREATED",
            iso(ctx["created_at"]),
        ]
        for step, transition in enumerate(ctx["path"], start=1):
            aid += 1
            actor_id = (
                ctx["applicant_id"] if transition.actor == "applicant" else ctx["reviewer_id"]
            )
            yield [
                aid,
                ctx["application_id"],
                "",
                "",
                actor_id,
                transition.audit_event,
                iso(ctx["created_at"] + timedelta(minutes=step)),
            ]


def loader_sql() -> str:
    return """\\set ON_ERROR_STOP on
\\if :{?m8_confirm_synthetic_reset}
\\else
\\echo 'ERROR: pass -v m8_confirm_synthetic_reset=true to load the M8 synthetic namespace'
\\quit
\\endif
\\if :m8_confirm_synthetic_reset
\\else
\\echo 'ERROR: m8_confirm_synthetic_reset must be true'
\\quit
\\endif

BEGIN;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM programs
    WHERE id BETWEEN 8000000000 AND 8999999999
      AND code NOT LIKE 'M8-P%'
  ) THEN
    RAISE EXCEPTION 'M8 program ID namespace collision';
  END IF;
  IF EXISTS (
    SELECT 1 FROM users
    WHERE id BETWEEN 8000000000 AND 8999999999
      AND username NOT LIKE 'm8-%'
  ) THEN
    RAISE EXCEPTION 'M8 user ID namespace collision';
  END IF;
  IF EXISTS (
    SELECT 1 FROM applications
    WHERE id BETWEEN 8000000000 AND 8999999999
      AND project_title NOT LIKE 'M8 Project %'
  ) THEN
    RAISE EXCEPTION 'M8 application ID namespace collision';
  END IF;
END
$$;

DELETE FROM attachments
WHERE application_id IN (
  SELECT id FROM applications
  WHERE id BETWEEN 8000000000 AND 8999999999
     OR program_id BETWEEN 8000000000 AND 8099999999
);

DELETE FROM audit_events
WHERE id BETWEEN 8000000000 AND 8999999999
   OR program_id BETWEEN 8000000000 AND 8099999999
   OR application_id IN (
        SELECT id FROM applications
        WHERE id BETWEEN 8000000000 AND 8999999999
           OR program_id BETWEEN 8000000000 AND 8099999999
      );

DELETE FROM application_status_history
WHERE id BETWEEN 8000000000 AND 8999999999
   OR application_id IN (
        SELECT id FROM applications
        WHERE id BETWEEN 8000000000 AND 8999999999
           OR program_id BETWEEN 8000000000 AND 8099999999
      );

DELETE FROM applications
WHERE id BETWEEN 8000000000 AND 8999999999
   OR program_id BETWEEN 8000000000 AND 8099999999;

DELETE FROM users
WHERE id BETWEEN 8000000000 AND 8999999999;

DELETE FROM programs
WHERE id BETWEEN 8000000000 AND 8999999999;

\\copy programs(id,title,description,code,publication_status,application_open_at,application_close_at,version,created_at,updated_at) FROM 'programs.csv' WITH (FORMAT csv, HEADER true)
\\copy users(id,username,password_hash,display_name,email,role,created_at,updated_at) FROM 'users.csv' WITH (FORMAT csv, HEADER true)
\\copy applications(id,program_id,applicant_id,reviewer_id,title,content,status,created_at,updated_at,version,applicant_organization_name,project_title,short_summary,requested_amount,detailed_plan) FROM 'applications.csv' WITH (FORMAT csv, HEADER true)
\\copy application_status_history(id,application_id,from_status,to_status,changed_by,changed_at,reason) FROM 'application_status_history.csv' WITH (FORMAT csv, HEADER true)
\\copy audit_events(id,application_id,program_id,subject_user_id,actor_id,event_type,occurred_at) FROM 'audit_events.csv' WITH (FORMAT csv, HEADER true)

COMMIT;
"""


def verification_sql(spec: DatasetSpec) -> str:
    expected_history = history_count(spec.applications)
    expected_users = spec.applicants + spec.reviewers
    expected_audits = spec.applications + expected_history
    return f"""\\set ON_ERROR_STOP on

DO $$
DECLARE
  application_count bigint;
  history_count bigint;
  user_count bigint;
  program_count bigint;
  audit_count bigint;
BEGIN
  SELECT count(*) INTO application_count
  FROM applications WHERE id BETWEEN 8200000001 AND 8299999999;
  SELECT count(*) INTO history_count
  FROM application_status_history WHERE id BETWEEN 8300000001 AND 8399999999;
  SELECT count(*) INTO user_count
  FROM users WHERE id BETWEEN 8100000001 AND 8199999999;
  SELECT count(*) INTO program_count
  FROM programs WHERE id BETWEEN 8000000001 AND 8099999999;
  SELECT count(*) INTO audit_count
  FROM audit_events WHERE id BETWEEN 8400000001 AND 8499999999;

  IF application_count <> {spec.applications} THEN
    RAISE EXCEPTION 'M8 application count mismatch: %', application_count;
  END IF;
  IF history_count <> {expected_history} THEN
    RAISE EXCEPTION 'M8 history count mismatch: %', history_count;
  END IF;
  IF user_count <> {expected_users} THEN
    RAISE EXCEPTION 'M8 user count mismatch: %', user_count;
  END IF;
  IF program_count <> {spec.programs} THEN
    RAISE EXCEPTION 'M8 program count mismatch: %', program_count;
  END IF;
  IF audit_count <> {expected_audits} THEN
    RAISE EXCEPTION 'M8 audit count mismatch: %', audit_count;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM applications a
    LEFT JOIN LATERAL (
      SELECT h.to_status, count(*) OVER () AS history_rows
      FROM application_status_history h
      WHERE h.application_id = a.id
      ORDER BY h.changed_at DESC, h.id DESC
      LIMIT 1
    ) last_history ON true
    WHERE a.id BETWEEN 8200000001 AND 8299999999
      AND (
        a.version <> COALESCE(last_history.history_rows, 0)
        OR (last_history.to_status IS NULL AND a.status <> 'DRAFT')
        OR (last_history.to_status IS NOT NULL AND a.status <> last_history.to_status)
      )
  ) THEN
    RAISE EXCEPTION 'M8 application/history invariant mismatch';
  END IF;
END
$$;
"""


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def generate_dataset(output: Path, spec: DatasetSpec, seed: int) -> dict[str, object]:
    output.mkdir(parents=True, exist_ok=True)

    write_csv(
        output / "programs.csv",
        [
            "id",
            "title",
            "description",
            "code",
            "publication_status",
            "application_open_at",
            "application_close_at",
            "version",
            "created_at",
            "updated_at",
        ],
        program_rows(spec, seed),
    )
    write_csv(
        output / "users.csv",
        ["id", "username", "password_hash", "display_name", "email", "role", "created_at", "updated_at"],
        user_rows(spec, seed),
    )
    write_csv(
        output / "applications.csv",
        [
            "id",
            "program_id",
            "applicant_id",
            "reviewer_id",
            "title",
            "content",
            "status",
            "created_at",
            "updated_at",
            "version",
            "applicant_organization_name",
            "project_title",
            "short_summary",
            "requested_amount",
            "detailed_plan",
        ],
        application_rows(spec, seed),
    )
    write_csv(
        output / "application_status_history.csv",
        ["id", "application_id", "from_status", "to_status", "changed_by", "changed_at", "reason"],
        history_rows(spec, seed),
    )
    write_csv(
        output / "audit_events.csv",
        ["id", "application_id", "program_id", "subject_user_id", "actor_id", "event_type", "occurred_at"],
        audit_rows(spec, seed),
    )

    (output / "load.sql").write_text(loader_sql(), encoding="utf-8")
    (output / "verify.sql").write_text(verification_sql(spec), encoding="utf-8")

    data_files = [
        "programs.csv",
        "users.csv",
        "applications.csv",
        "application_status_history.csv",
        "audit_events.csv",
    ]
    manifest = {
        "schema_version": 1,
        "profile": spec.name,
        "seed": seed,
        "namespace": {"min": NAMESPACE_MIN, "max": NAMESPACE_MAX},
        "counts": {
            "programs": spec.programs,
            "users": spec.applicants + spec.reviewers,
            "applicants": spec.applicants,
            "reviewers": spec.reviewers,
            "applications": spec.applications,
            "application_status_history": history_count(spec.applications),
            "audit_events": spec.applications + history_count(spec.applications),
        },
        "files": {name: sha256(output / name) for name in data_files},
        "bulk_users_login_enabled": False,
        "attachments_seeded": False,
    }
    (output / "dataset-manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return manifest
