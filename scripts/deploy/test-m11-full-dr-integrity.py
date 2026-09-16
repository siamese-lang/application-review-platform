#!/usr/bin/env python3
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(path: str, *tokens: str) -> None:
    text = read(path)
    for token in tokens:
        if token not in text:
            raise SystemExit(f"{path}: missing required token: {token}")


require(
    "deploy/verify-m11-full-dr-integrity.sh",
    "output -json full_dr_inventory",
    "output -json backup",
    "full-dr-integrity.yml",
    "m11_checkpoint_cutoff",
    "m11_expected_checkpoint_available",
)
wrapper = read("deploy/verify-m11-full-dr-integrity.sh")
if "StrictHostKeyChecking=no" in wrapper:
    raise SystemExit("full DR integrity wrapper weakens SSH host verification")
for forbidden in [
    "output -json inventory",
    '"edge-01"',
    '"app-01"',
    '"db-01"',
]:
    if forbidden in wrapper:
        raise SystemExit(f"full DR integrity wrapper violates DR isolation: {forbidden}")

require(
    "config/ansible/full-dr-integrity.yml",
    "hosts: db",
    "hosts: backup",
    "reviewer_state_mismatch",
    "audit_subject_mismatch",
    "history_actor_role_mismatch",
    "checkpoint_available_attachments",
    "verify_m11_full_dr_integrity.py",
)

require(
    "scripts/restore/verify_m11_full_dr_integrity.py",
    "M11_FULL_DR_CHECKPOINT_AVAILABLE_ATTACHMENTS",
    "M11_FULL_DR_TARGET_MANIFEST_OBJECTS_VERIFIED",
    "M11_FULL_DR_INTEGRITY=PASS",
    "target SHA-256 mismatch",
    "DB/manifest SHA-256 mismatch",
)

path = ROOT / "deploy/verify-m11-full-dr-integrity.sh"
if not (path.stat().st_mode & 0o111):
    raise SystemExit("deploy/verify-m11-full-dr-integrity.sh: expected executable mode")

subprocess.run(["bash", "-n", str(path)], check=True)
subprocess.run(
    ["python3", "-m", "py_compile", str(ROOT / "scripts/restore/verify_m11_full_dr_integrity.py")],
    check=True,
)

print("M11 Phase 4 full DR integrity verification contract: PASS")
