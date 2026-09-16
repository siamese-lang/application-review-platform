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
    "config/ansible/m11-backup-closeout.yml",
    "Remove M11 pgBackRest archive drop-in",
    "pgbackrest-archive.conf",
    "Restart PostgreSQL after removing temporary archive wiring",
    "current_setting('archive_mode')",
    "current_setting('archive_command')",
    "m11_archive_state_after.stdout == 'off|'",
    "Remove stale database-host pgBackRest repository configuration",
    "path: /etc/pgbackrest/pgbackrest.conf",
)

require(
    "deploy/closeout-m11-backup.sh",
    "output -json inventory",
    "generate-inventory.py",
    "with-oslogin-ssh.py",
    "m11-backup-closeout.yml",
)

wrapper = read("deploy/closeout-m11-backup.sh")
for forbidden in ("StrictHostKeyChecking=no", "ssh-keyscan", "curl -k", "--insecure"):
    if forbidden in wrapper:
        raise SystemExit(f"backup closeout wrapper contains forbidden token: {forbidden}")

print("M11 backup closeout contract: PASS")
