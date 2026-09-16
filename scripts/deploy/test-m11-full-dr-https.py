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
    "deploy/bootstrap-m11-full-dr-ip-tls.sh",
    "output -json full_dr",
    "output -json full_dr_inventory",
    "dr-edge-01",
    "dr-app-01",
    "dr-db-01",
    "dr-storage-01",
    "dr-storage-02",
    "dr-storage-03",
    "generate-inventory.py",
    "--preferred-profile shortlived",
    "--ip-address",
    "full-dr-edge-https.yml",
    "StrictHostKeyChecking=yes",
    "https://$edge_public_ip/api/v1/programs?size=1",
    "M11_FULL_DR_HTTPS=PASS",
)
wrapper = read("deploy/bootstrap-m11-full-dr-ip-tls.sh")
for forbidden in [
    "output -raw edge_public_ip",
    "output -json inventory",
    '"edge-01"',
    "site.yml",
    "StrictHostKeyChecking=no",
    "--insecure",
    " -k ",
]:
    if forbidden in wrapper:
        raise SystemExit(f"full DR HTTPS bootstrap violates isolation/TLS boundary: {forbidden}")

require(
    "config/ansible/full-dr-edge-https.yml",
    "hosts: edge",
    "app_private_ip: \"{{ hostvars[groups['app'][0]].ansible_host }}\"",
    "roles: [edge]",
)

path = ROOT / "deploy/bootstrap-m11-full-dr-ip-tls.sh"
if not (path.stat().st_mode & 0o111):
    raise SystemExit("deploy/bootstrap-m11-full-dr-ip-tls.sh: expected executable mode")

subprocess.run(["bash", "-n", str(path)], check=True)

print("M11 Phase 4 full DR HTTPS bootstrap contract: PASS")
