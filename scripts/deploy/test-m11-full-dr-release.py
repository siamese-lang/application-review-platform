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
    "deploy/deploy-m11-full-dr-release.sh",
    "ARP_RELEASE_BUNDLE_DIR",
    "ARP_RELEASE_SHA",
    "ARP_RUNTIME_SECRETS_FILE",
    "verify-release-bundle.sh",
    "output -json full_dr_inventory",
    "dr-edge-01",
    "dr-app-01",
    "dr-db-01",
    "dr-storage-01",
    "dr-storage-02",
    "dr-storage-03",
    "generate-inventory.py",
    "--inventory",
    "release.yml",
)
wrapper = read("deploy/deploy-m11-full-dr-release.sh")
for forbidden in [
    "output -json inventory",
    '"app-01"',
    '"edge-01"',
    '"db-01"',
    "10.40.0.20",
    "10.40.0.30",
    "git checkout",
    "mvnw",
    "npm",
    "StrictHostKeyChecking=no",
]:
    if forbidden in wrapper:
        raise SystemExit(f"full DR release wrapper violates isolation/exact-release boundary: {forbidden}")

require(
    "config/ansible/release.yml",
    "hosts: app",
    "hosts: edge",
    "db_host: \"{{ groups['db'][0] }}\"",
    "Wait for activated backend API readiness",
    "Activate frontend after backend succeeds",
)

path = ROOT / "deploy/deploy-m11-full-dr-release.sh"
if not (path.stat().st_mode & 0o111):
    raise SystemExit("deploy/deploy-m11-full-dr-release.sh: expected executable mode")

subprocess.run(["bash", "-n", str(path)], check=True)

print("M11 Phase 4 full DR release activation contract: PASS")
