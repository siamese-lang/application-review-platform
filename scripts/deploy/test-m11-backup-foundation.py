#!/usr/bin/env python3
from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(path: str, *tokens: str) -> None:
    text = read(path)
    for token in tokens:
        if token not in text:
            raise SystemExit(f"{path}: missing required token: {token}")


variables = read("infra/opentofu/variables.tf")
if 'variable "enable_backup"' not in variables or "default     = false" not in variables:
    raise SystemExit("M11 backup infrastructure must remain opt-in by default")

require(
    "infra/opentofu/compute.tf",
    'resource "google_compute_instance" "backup"',
    'count        = var.enable_backup ? 1 : 0',
    'name         = "backup-01"',
    '"arp-backup"',
    'device_name = "arp-backup-data"',
)
compute = read("infra/opentofu/compute.tf")
backup_start = compute.find('resource "google_compute_instance" "backup"')
if backup_start < 0:
    raise SystemExit("missing backup-01 resource")
backup_block = compute[backup_start:]
if "service_account" in backup_block:
    raise SystemExit("backup-01 must not inherit a broad workload service account")

require(
    "infra/opentofu/disks.tf",
    'resource "google_compute_disk" "backup"',
    'name  = "arp-backup-01-data"',
)
require(
    "infra/opentofu/network.tf",
    'resource "google_compute_subnetwork" "backup"',
    'resource "google_compute_router" "backup"',
    'resource "google_compute_router_nat" "backup"',
)
require(
    "infra/opentofu/firewall.tf",
    'resource "google_compute_firewall" "db_backup_ssh"',
    'resource "google_compute_firewall" "backup_db_ssh"',
    'resource "google_compute_firewall" "backup_garage_s3"',
    'source_tags = ["arp-backup"]',
    'target_tags = ["arp-storage"]',
)
require(
    "infra/opentofu/outputs.tf",
    'output "backup"',
    '"backup-01"',
    'role       = "backup"',
)
require(
    "deploy/generate-inventory.py",
    '"backup"',
)
require(
    "config/ansible/backup.yml",
    "roles: [common, backup]",
    "roles: [pgbackrest_db]",
)
require(
    "config/ansible/roles/backup/tasks/main.yml",
    "acl",
    "pgbackrest",
    "python3-boto3",
    "/srv/backup/pgbackrest",
    "/srv/backup/objects",
    "ssh-keygen",
    "known_hosts",
    "garage_object_backup.py",
    "verify_object_backup.py",
)
require(
    "config/ansible/roles/pgbackrest_db/tasks/main.yml",
    "name: [acl, pgbackrest]",
    "Authorize repository service on database for pgBackRest only",
    "Authorize database service on repository for pgBackRest only",
    "no-agent-forwarding,no-X11-forwarding,no-port-forwarding",
    'command="/usr/bin/pgbackrest',
    "stanza-create",
    "--stanza=arp, check",
)
require(
    "config/ansible/roles/pgbackrest_db/templates/postgresql-archive.conf.j2",
    "archive_mode = on",
    "pgbackrest --stanza=arp archive-push %p",
    "archive_timeout = '60s'",
)
require(
    "scripts/backup/garage_object_backup.py",
    "GARAGE_ACCESS_KEY",
    "GARAGE_SECRET_KEY",
    '"object_key"',
    '"size"',
    '"sha256"',
    '"backup_timestamp"',
)
require(
    "scripts/backup/verify_object_backup.py",
    "M11_OBJECT_BACKUP_VERIFY=PASS",
    "SHA-256 mismatch",
)

for path in [
    "config/ansible/roles/backup/tasks/main.yml",
    "config/ansible/roles/pgbackrest_db/tasks/main.yml",
    "scripts/backup/run-pgbackrest-full.sh",
]:
    text = read(path)
    if "StrictHostKeyChecking=no" in text or "ssh-keyscan" in text:
        raise SystemExit(f"{path}: M11 must not weaken SSH host verification")

schema = read("config/secrets/runtime.schema.yaml")
for forbidden in ["pgbackrest_private_key", "backup_private_key"]:
    if forbidden in schema:
        raise SystemExit("M11 service SSH private keys must be generated on-host, not added to runtime secrets")

subprocess.run(
    ["python3", "-m", "py_compile",
     str(ROOT / "scripts/backup/garage_object_backup.py"),
     str(ROOT / "scripts/backup/verify_object_backup.py"),
     str(ROOT / "scripts/backup/test-m11-backup-tooling.py")],
    check=True,
)
subprocess.run(
    ["python3", str(ROOT / "scripts/backup/test-m11-backup-tooling.py")],
    check=True,
)
subprocess.run(
    ["bash", "-n", str(ROOT / "scripts/backup/run-pgbackrest-full.sh")],
    check=True,
)

print("M11 backup/recovery foundation contract: PASS")
