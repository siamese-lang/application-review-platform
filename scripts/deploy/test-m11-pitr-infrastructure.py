#!/usr/bin/env python3
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
if 'variable "enable_recovery_db"' not in variables:
    raise SystemExit("missing enable_recovery_db variable")
block = variables[variables.index('variable "enable_recovery_db"'):]
if "default     = false" not in block:
    raise SystemExit("M11 recovery DB infrastructure must remain opt-in by default")

require(
    "infra/opentofu/compute.tf",
    'resource "google_compute_instance" "recovery_db"',
    'name         = "recovery-db-01"',
    'tags         = ["arp-recovery-db", "arp-managed"]',
    'device_name = "arp-recovery-db-data"',
    'condition     = var.enable_backup',
)
compute = read("infra/opentofu/compute.tf")
start = compute.index('resource "google_compute_instance" "recovery_db"')
recovery_block = compute[start:]
if "service_account" in recovery_block:
    raise SystemExit("recovery-db-01 must not inherit a broad workload service account")
if "access_config" in recovery_block:
    raise SystemExit("recovery-db-01 must not have a public IP")

require(
    "infra/opentofu/disks.tf",
    'resource "google_compute_disk" "recovery_db"',
    'name  = "arp-recovery-db-01-data"',
    'type  = "pd-standard"',
)
require(
    "infra/opentofu/firewall.tf",
    'resource "google_compute_firewall" "backup_recovery_db_ssh"',
    'resource "google_compute_firewall" "recovery_db_backup_ssh"',
    'source_tags = ["arp-backup"]',
    'target_tags = ["arp-recovery-db"]',
    'source_tags = ["arp-recovery-db"]',
    'target_tags = ["arp-backup"]',
)
require(
    "infra/opentofu/outputs.tf",
    'output "recovery_db"',
    '"recovery-db-01"',
    'role       = "recovery_db"',
)
require(
    "deploy/generate-inventory.py",
    '"recovery_db"',
)

firewall = read("infra/opentofu/firewall.tf")
forbidden = [
    'target_tags = ["arp-recovery-db"]\n  allow {\n    protocol = "tcp"\n    ports    = ["5432"]',
]
for token in forbidden:
    if token in firewall:
        raise SystemExit("PITR recovery DB must not expose PostgreSQL ingress")

print("M11 Phase 2 recovery DB infrastructure contract: PASS")
