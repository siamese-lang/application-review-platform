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


require(
    "config/ansible/recovery-db.yml",
    "hosts: recovery_db",
    "roles: [common, recovery_db]",
)

require(
    "config/ansible/roles/recovery_db/tasks/main.yml",
    "postgresql",
    "pgbackrest",
    "/dev/disk/by-id/google-arp-recovery-db-data",
    "/srv/postgresql/data",
    "Prevent automatic recovery cluster startup",
    "Create recovery PostgreSQL data directory without initializing it",
    "Authorize recovery database service on repository for pgBackRest only",
    "no-agent-forwarding,no-X11-forwarding,no-port-forwarding",
    'command="/usr/bin/pgbackrest',
    "Pin backup host key for recovery PostgreSQL service",
    "Require exact pgBackRest version match",
    "Verify recovery host can read the retained repository",
    "Verify recovery PostgreSQL remains stopped before PITR",
)

tasks = read("config/ansible/roles/recovery_db/tasks/main.yml")
for forbidden in [
    "initdb",
    "pgbackrest --stanza=arp restore",
    "--type=time",
    "--target=",
    "StrictHostKeyChecking=no",
    "ssh-keyscan",
]:
    if forbidden in tasks:
        raise SystemExit(f"recovery foundation must not execute PITR or weaken SSH: {forbidden}")

require(
    "config/ansible/roles/recovery_db/templates/pgbackrest.conf.j2",
    "[arp]",
    "pg1-path=/srv/postgresql/data",
    "repo1-host={{ backup_private_ip }}",
    "repo1-host-user=pgbackrest",
    "repo1-path=/srv/backup/pgbackrest",
)

require(
    "config/ansible/roles/recovery_db/templates/postgresql-recovery.conf.j2",
    "listen_addresses = '127.0.0.1'",
    "data_directory = '/srv/postgresql/data'",
)

print("M11 Phase 2 recovery DB foundation contract: PASS")
