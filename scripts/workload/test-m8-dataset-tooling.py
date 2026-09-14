#!/usr/bin/env python3
from __future__ import annotations

import csv
import hashlib
import importlib.util
import tempfile
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts/workload/synthetic_dataset.py"

spec = importlib.util.spec_from_file_location("m8_synthetic_dataset", MODULE_PATH)
if spec is None or spec.loader is None:
    raise SystemExit("failed to load synthetic_dataset module")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

DatasetSpec = module.DatasetSpec
generate_dataset = module.generate_dataset
history_count = module.history_count
load_profiles = module.load_profiles
API_VERIFICATION_PAYLOAD = module.API_VERIFICATION_PAYLOAD


def digest_tree(path: Path) -> dict[str, str]:
    result = {}
    for file in sorted(p for p in path.iterdir() if p.is_file()):
        result[file.name] = hashlib.sha256(file.read_bytes()).hexdigest()
    return result


def rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def load_properties(path: Path) -> dict[str, str]:
    result = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or line.lstrip().startswith("#"):
            continue
        key, value = line.split("=", 1)
        result[key] = value
    return result


profiles = load_profiles(ROOT / "workload/datasets/profiles.json")
if profiles["S"].applications != 10_000:
    raise SystemExit("S profile must remain 10,000 applications")
if profiles["M"].applications != 100_000:
    raise SystemExit("M profile must remain 100,000 applications")
if profiles["L"].applications != 500_000:
    raise SystemExit("L profile must remain 500,000 applications")
if history_count(profiles["S"].applications) != 39_990:
    raise SystemExit("S history target drifted")
if history_count(profiles["M"].applications) != 399_990:
    raise SystemExit("M history target drifted")
if history_count(profiles["L"].applications) != 1_999_992:
    raise SystemExit("L history target drifted")

small = DatasetSpec(name="T", applications=120, applicants=12, reviewers=6, programs=4)

with tempfile.TemporaryDirectory() as temp:
    root = Path(temp)
    first = root / "first"
    second = root / "second"
    different = root / "different"

    manifest = generate_dataset(first, small, 20260914)
    generate_dataset(second, small, 20260914)
    generate_dataset(different, small, 20260915)

    if digest_tree(first) != digest_tree(second):
        raise SystemExit("same seed/spec did not produce byte-identical dataset bundles")
    if digest_tree(first)["applications.csv"] == digest_tree(different)["applications.csv"]:
        raise SystemExit("different seed did not change application dataset bytes")

    programs = rows(first / "programs.csv")
    users = rows(first / "users.csv")
    applications = rows(first / "applications.csv")
    histories = rows(first / "application_status_history.csv")
    audits = rows(first / "audit_events.csv")

    if len(programs) != small.programs:
        raise SystemExit("program count mismatch")
    if len(users) != small.applicants + small.reviewers:
        raise SystemExit("user count mismatch")
    if len(applications) != small.applications:
        raise SystemExit("application count mismatch")
    if len(histories) != history_count(small.applications):
        raise SystemExit("history count mismatch")
    if len(audits) != small.applications + len(histories):
        raise SystemExit("audit count mismatch")

    if manifest["counts"]["application_status_history"] != len(histories):
        raise SystemExit("manifest history count mismatch")
    if manifest["bulk_users_login_enabled"] is not False:
        raise SystemExit("bulk users must remain non-login fixtures")
    if manifest["attachments_seeded"] is not False:
        raise SystemExit("Phase 2 must not claim attachment fixture generation")

    program_ids = {row["id"] for row in programs}
    user_roles = {row["id"]: row["role"] for row in users}
    applicant_ids = {uid for uid, role in user_roles.items() if role == "APPLICANT"}
    reviewer_ids = {uid for uid, role in user_roles.items() if role == "REVIEWER"}
    app_by_id = {row["id"]: row for row in applications}

    histories_by_app: dict[str, list[dict[str, str]]] = defaultdict(list)
    for history in histories:
        if history["application_id"] not in app_by_id:
            raise SystemExit("history references unknown application")
        histories_by_app[history["application_id"]].append(history)

    valid_transitions = {
        ("DRAFT", "SUBMITTED"),
        ("SUBMITTED", "IN_REVIEW"),
        ("IN_REVIEW", "NEEDS_REVISION"),
        ("NEEDS_REVISION", "SUBMITTED"),
        ("IN_REVIEW", "APPROVED"),
        ("IN_REVIEW", "REJECTED"),
    }

    for application in applications:
        if application["program_id"] not in program_ids:
            raise SystemExit("application references unknown program")
        if application["applicant_id"] not in applicant_ids:
            raise SystemExit("application references non-applicant owner")
        if application["title"] != application["project_title"]:
            raise SystemExit("legacy title and structured project title diverged")
        if application["content"] != application["detailed_plan"]:
            raise SystemExit("legacy content and structured detailed plan diverged")

        history = histories_by_app.get(application["id"], [])
        if int(application["version"]) != len(history):
            raise SystemExit("application version does not equal generated transition count")

        expected_source = "DRAFT"
        for item in history:
            transition = (item["from_status"], item["to_status"])
            if transition not in valid_transitions:
                raise SystemExit(f"invalid generated transition: {transition}")
            if item["from_status"] != expected_source:
                raise SystemExit("generated status history is not contiguous")

            actor_id = item["changed_by"]
            if item["to_status"] == "SUBMITTED":
                if actor_id != application["applicant_id"]:
                    raise SystemExit("submission transition must be performed by application owner")
            elif actor_id not in reviewer_ids:
                raise SystemExit("review transition must be performed by a reviewer")

            expected_source = item["to_status"]

        expected_final = history[-1]["to_status"] if history else "DRAFT"
        if application["status"] != expected_final:
            raise SystemExit("application final status does not match final history entry")

        reviewer_id = application["reviewer_id"]
        if len(history) >= 2:
            if reviewer_id not in reviewer_ids:
                raise SystemExit("review-started application must retain an assigned reviewer")
        elif reviewer_id:
            raise SystemExit("draft/submitted application must not have an assigned reviewer")

    audit_by_app: dict[str, list[dict[str, str]]] = defaultdict(list)
    for audit in audits:
        if audit["application_id"] not in app_by_id:
            raise SystemExit("audit references unknown application")
        if audit["program_id"] or audit["subject_user_id"]:
            raise SystemExit("application audit fixture must have exactly one application subject")
        if audit["actor_id"] not in user_roles:
            raise SystemExit("audit references unknown actor")
        audit_by_app[audit["application_id"]].append(audit)

    for application in applications:
        application_audits = audit_by_app[application["id"]]
        if len(application_audits) != 1 + len(histories_by_app.get(application["id"], [])):
            raise SystemExit("audit count must equal create event plus generated transitions")
        if application_audits[0]["event_type"] != "APPLICATION_CREATED":
            raise SystemExit("first audit event must be APPLICATION_CREATED")

    load_sql = (first / "load.sql").read_text(encoding="utf-8")
    for token in [
        "m8_confirm_synthetic_reset",
        "M8 program ID namespace collision",
        "M8 user ID namespace collision",
        "M8 application ID namespace collision",
        "DELETE FROM attachments",
        "\\copy applications",
    ]:
        if token not in load_sql:
            raise SystemExit(f"guarded loader contract missing: {token}")

api_props = load_properties(ROOT / "app/src/test/resources/m8/api-verification.properties")
if api_props != API_VERIFICATION_PAYLOAD:
    raise SystemExit("API verification fixture drifted from generator field pattern")

print("M8 Phase 2 deterministic dataset tooling: PASS")
