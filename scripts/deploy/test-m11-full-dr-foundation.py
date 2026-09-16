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
    "config/ansible/full-dr-foundation.yml",
    "hosts: edge:app:db:storage",
    "hosts: db",
    "roles: [recovery_db]",
    "/dev/disk/by-id/google-arp-data",
    "recovery_db_app_private_ip",
    "hosts: storage",
    "roles: [garage]",
    "hosts: app",
    "roles: [release_runtime, garage_proxy, app]",
    "hosts: edge",
    "roles: [release_runtime, edge]",
)
if "alloy" in read("config/ansible/full-dr-foundation.yml"):
    raise SystemExit("full DR foundation must not require the retained observability path")

require(
    "deploy/configure-m11-full-dr-foundation.sh",
    "output -json full_dr_inventory",
    "output -json backup",
    "dr-edge-01",
    "dr-app-01",
    "dr-db-01",
    "dr-storage-01",
    "dr-storage-02",
    "dr-storage-03",
    "generate-inventory.py",
    "full-dr-foundation.yml",
)
configure = read("deploy/configure-m11-full-dr-foundation.sh")
if "output -json inventory" in configure:
    raise SystemExit("full DR foundation must not use the retained-runtime inventory output")

require(
    "config/ansible/roles/recovery_db/tasks/main.yml",
    "recovery_db_disk_device | default('/dev/disk/by-id/google-arp-recovery-db-data')",
    "Configure recovery database client authentication when explicitly enabled",
    "recovery_db_app_private_ip",
    "Verify recovery PostgreSQL remains stopped before restore",
)
require(
    "config/ansible/roles/recovery_db/templates/postgresql-recovery.conf.j2",
    "recovery_db_listen_addresses | default",
    "data_directory = '/srv/postgresql/data'",
)
require(
    "config/ansible/roles/recovery_db/templates/pg_hba.conf.j2",
    "host arp arp_flyway {{ recovery_db_app_private_ip }}/32 scram-sha-256",
    "host arp arp_app {{ recovery_db_app_private_ip }}/32 scram-sha-256",
)

require(
    "scripts/restore/run-m11-full-dr-db-restore.sh",
    "--set=\"$backup_label\"",
    "--type=immediate",
    "--target-action=promote",
    "full DR data directory is not empty",
    "M11_FULL_DR_DB_BACKUP_LABEL",
    "M11_FULL_DR_DB_RESTORE_MS",
    "M11_FULL_DR_DB_READY_MS",
    "M11_FULL_DR_DB_VERIFIED_MS",
    "M11_FULL_DR_DB_RESTORE=PASS",
)
restore = read("scripts/restore/run-m11-full-dr-db-restore.sh")
for forbidden in [
    "--type=time",
    "--target=",
    "rm -rf /srv/postgresql",
    "10.40.0.30",
    "StrictHostKeyChecking=no",
]:
    if forbidden in restore:
        raise SystemExit(f"full DR DB restore violates checkpoint isolation: {forbidden}")

subprocess.run(["bash", "-n", str(ROOT / "deploy/configure-m11-full-dr-foundation.sh")], check=True)
subprocess.run(["bash", "-n", str(ROOT / "scripts/restore/run-m11-full-dr-db-restore.sh")], check=True)

print("M11 Phase 4 full DR foundation contract: PASS")
