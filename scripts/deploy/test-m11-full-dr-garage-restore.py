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
    "deploy/restore-m11-full-dr-garage.sh",
    "output -json full_dr_inventory",
    "output -json backup",
    "dr-storage-01",
    "dr-storage-02",
    "dr-storage-03",
    "generate-inventory.py",
    "full-dr-garage-restore.yml",
    "m11_checkpoint_id=$checkpoint_id",
    "m11_manifest_sha256=$manifest_sha256",
)
wrapper = read("deploy/restore-m11-full-dr-garage.sh")
if "scripts/restore/m11-full-dr-garage-restore.yml" in wrapper:
    raise SystemExit("full DR Garage playbook must live under config/ansible so group_vars load")
for forbidden in [
    "output -json inventory",
    "storage-01 storage-02 storage-03",
    "10.40.0.41",
    "StrictHostKeyChecking=no",
]:
    if forbidden in wrapper:
        raise SystemExit(f"full DR Garage wrapper violates isolation boundary: {forbidden}")

require(
    "config/ansible/group_vars/all/main.yml",
    "garage_rpc_port: 3901",
    "garage_s3_port: 3900",
    "garage_bucket: application-review",
)

require(
    "config/ansible/full-dr-garage-restore.yml",
    "hosts: storage",
    "Require exactly three DR Garage nodes",
    "node, id, -q",
    "layout",
    "bucket, create",
    "key import",
    "hosts: backup",
    "garage_object_restore.py",
    "m11_manifest_sha256",
    "m11_restore_secret_file",
    "become_user: pgbackrest",
    "Remove temporary Garage restore credential file",
)

require(
    "scripts/restore/garage_object_restore.py",
    "manifest SHA-256 mismatch",
    "target DR bucket is not empty; refusing overwrite",
    "source size mismatch",
    "source SHA-256 mismatch",
    "restored key set mismatch",
    "restored size mismatch",
    "restored SHA-256 mismatch",
    "M11_FULL_DR_OBJECT_COUNT",
    "M11_FULL_DR_OBJECT_MANIFEST_SHA256",
    "M11_FULL_DR_OBJECT_RESTORE_MS",
    "M11_FULL_DR_OBJECT_RESTORE=PASS",
)
restore = read("scripts/restore/garage_object_restore.py")
for forbidden in [
    "delete_object",
    "delete_objects",
    "rm -rf",
    "10.40.0.41",
]:
    if forbidden in restore:
        raise SystemExit(f"full DR object restore must not delete or target retained storage: {forbidden}")

wrapper_path = ROOT / "deploy/restore-m11-full-dr-garage.sh"
if not (wrapper_path.stat().st_mode & 0o111):
    raise SystemExit("deploy/restore-m11-full-dr-garage.sh: expected executable mode")

subprocess.run(["bash", "-n", str(wrapper_path)], check=True)
subprocess.run(
    ["python3", "-m", "py_compile", str(ROOT / "scripts/restore/garage_object_restore.py")],
    check=True,
)

print("M11 Phase 4 full DR Garage restore contract: PASS")
