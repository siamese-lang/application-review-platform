#!/usr/bin/env python3
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]

marker = (ROOT / "scripts/restore/run-m11-pitr-marker.sh").read_text(encoding="utf-8")
restore = (ROOT / "scripts/restore/run-m11-pitr-restore.sh").read_text(encoding="utf-8")

for token in [
    "M11_PITR_PRE",
    "M11_PITR_POST",
    "publication_status",
    "'DRAFT'",
    "M11_PITR_TARGET_TIME",
    "pg_switch_wal",
    "pgbackrest --stanza=arp check",
    "M11_PITR_MARKER_CLEANUP=PASS",
]:
    if token not in marker:
        raise SystemExit(f"marker tooling missing required token: {token}")

for forbidden in [
    "UPDATE applications",
    "DELETE FROM applications",
    "TRUNCATE",
    "DROP TABLE",
]:
    if forbidden in marker:
        raise SystemExit(f"marker tooling must not mutate retained application rows/schema: {forbidden}")

for token in [
    "--type=time",
    "--target=",
    "--target-action=promote",
    "recovery data directory is not empty",
    "M11_PITR_PRE_INCLUDED=PASS",
    "M11_PITR_POST_EXCLUDED=PASS",
    "M11_PITR_ORPHAN_APPLICATIONS",
    "M11_PITR_HISTORY_STATUS_MISMATCH",
    "M11_PITR_TERMINAL_HISTORY_MISSING",
    "M11_PITR_RESTORE=PASS",
]:
    if token not in restore:
        raise SystemExit(f"restore tooling missing required token: {token}")

for forbidden in [
    "rm -rf /srv/postgresql",
    "rm -rf /srv/postgresql/data",
    "db-01",
    "10.40.0.30",
    "StrictHostKeyChecking=no",
]:
    if forbidden in restore:
        raise SystemExit(f"restore tooling violates recovery isolation guardrail: {forbidden}")

subprocess.run(["bash", "-n", str(ROOT / "scripts/restore/run-m11-pitr-marker.sh")], check=True)
subprocess.run(["bash", "-n", str(ROOT / "scripts/restore/run-m11-pitr-restore.sh")], check=True)

print("M11 Phase 2 PITR execution tooling contract: PASS")
