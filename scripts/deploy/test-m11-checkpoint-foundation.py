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
    "config/ansible/roles/edge/files/arp-spa.conf",
    "location = /api {",
    "location ^~ /api/ {",
    "include /etc/nginx/snippets/arp-mutation-guard.conf;",
)
spa = read("config/ansible/roles/edge/files/arp-spa.conf")
if spa.count("include /etc/nginx/snippets/arp-mutation-guard.conf;") != 2:
    raise SystemExit("mutation guard must cover both /api and /api/ locations")

guard = read("config/ansible/roles/edge/files/arp-mutation-guard.conf")
if "return 503" in guard:
    raise SystemExit("managed mutation guard must be disabled by default")

require(
    "config/ansible/roles/edge/tasks/main.yml",
    "Install default-disabled M11 mutation guard",
    "src: arp-mutation-guard.conf",
    "dest: /etc/nginx/snippets/arp-mutation-guard.conf",
    "force: false",
)

require(
    "scripts/backup/run-m11-mutation-gate.sh",
    "{enable|disable|status}",
    "POST|PUT|PATCH|DELETE",
    "return 503;",
    "nginx -t",
    "systemctl reload nginx",
    "pgrep -P",
    "kill -0",
    "timed out waiting for pre-block Nginx worker",
    "M11_MUTATION_GATE=ENABLED",
    "M11_MUTATION_GATE=DISABLED",
)

script = read("scripts/backup/run-m11-mutation-gate.sh")
for forbidden in [
    "systemctl restart nginx",
    "service nginx restart",
    "kill -9",
    "StrictHostKeyChecking=no",
]:
    if forbidden in script:
        raise SystemExit(f"mutation gate must preserve graceful/drained behavior: {forbidden}")

require(
    "scripts/backup/m11-object-backup.yml",
    "hosts: backup",
    "Refuse to overwrite an existing checkpoint object backup",
    "/usr/local/lib/arp/garage_object_backup.py",
    "GARAGE_ACCESS_KEY: \"{{ garage_app_access_key }}\"",
    "GARAGE_SECRET_KEY: \"{{ garage_app_secret_key }}\"",
    "become_user: pgbackrest",
    "no_log: true",
)

require(
    "scripts/backup/run-m11-checkpoint.sh",
    "run-m11-mutation-gate.sh",
    "systemctl stop arp",
    "systemctl start arp",
    "PENDING",
    "DELETE_PENDING",
    "run-pgbackrest-full.sh",
    "m11-object-backup.yml",
    "verify_object_backup.py",
    "M11_CHECKPOINT_FREEZE_START",
    "M11_CHECKPOINT_BACKUP_VERIFIED_AT",
    "M11_CHECKPOINT_WRITES_RESUMED_AT",
    "M11_CHECKPOINT=PASS",
    "trap cleanup EXIT",
    "mutation_gate_left_enabled_for_safety",
)

for executable in [
    "scripts/backup/run-m11-mutation-gate.sh",
    "scripts/backup/run-m11-checkpoint.sh",
]:
    if not ((ROOT / executable).stat().st_mode & 0o111):
        raise SystemExit(f"{executable}: expected executable mode")

checkpoint = read("scripts/backup/run-m11-checkpoint.sh")
for forbidden in [
    "rm -rf /srv/backup",
    "rm -rf /srv/postgresql",
    "StrictHostKeyChecking=no",
    "systemctl restart arp",
]:
    if forbidden in checkpoint:
        raise SystemExit(f"checkpoint orchestrator violates recovery guardrail: {forbidden}")

subprocess.run(
    ["bash", "-n", str(ROOT / "scripts/backup/run-m11-mutation-gate.sh")],
    check=True,
)
subprocess.run(
    ["bash", "-n", str(ROOT / "scripts/backup/run-m11-checkpoint.sh")],
    check=True,
)

print("M11 Phase 3 checkpoint foundation contract: PASS")
