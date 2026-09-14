#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, token: str, context: str) -> None:
    if token not in text:
        raise SystemExit(f"missing {context}: {token}")


tool_versions = {}
for line in read("workload/tool-versions.env").splitlines():
    if not line.strip():
        continue
    key, value = line.split("=", 1)
    tool_versions[key] = value

expected_version = "2.2.0"
expected_checksum = "58b6468440332f882dba76efa87fb3b6d6eea0e3bd96090e3a5d5159f35832e0"

if tool_versions.get("K6_VERSION") != expected_version:
    raise SystemExit("unexpected k6 version pin")
if tool_versions.get("K6_LINUX_AMD64_DEB_SHA256") != expected_checksum:
    raise SystemExit("unexpected k6 deb checksum pin")

role = read("config/ansible/roles/loadgen/tasks/main.yml")
playbook = read("config/ansible/loadgen.yml")
configure = read("deploy/configure-loadgen.sh")
ci = read(".github/workflows/baseline-ci.yml")

for token in [
    "k6_version is defined",
    "k6_linux_amd64_deb_sha256 is defined",
    "k6-v{{ k6_version }}-linux-amd64.deb",
    'checksum: "sha256:{{ k6_linux_amd64_deb_sha256 }}"',
    "ansible.builtin.apt:",
    "ansible.builtin.command: /usr/bin/k6 version",
    "'k6 v' + k6_version in k6_version_output.stdout",
]:
    require(role, token, "pinned k6 role contract")

if expected_version in role or expected_checksum in role:
    raise SystemExit("loadgen role must consume workload/tool-versions.env metadata, not duplicate pins")

for token in [
    "- hosts: loadgen",
    "roles: [common, loadgen]",
]:
    require(playbook, token, "loadgen playbook contract")

for token in [
    "ARP_EXPECTED_SOURCE_SHA",
    "workload/tool-versions.env",
    "K6_VERSION",
    "K6_LINUX_AMD64_DEB_SHA256",
    "tofu -chdir=",
    "output -json loadgen",
    '"name": "loadgen-01"',
    '"private_ip": "10.50.0.10"',
    '"region": "asia-northeast1"',
    '"zone": "asia-northeast1-a"',
    "inventory_file=$(mktemp --suffix=.yml)",
    "ansible-galaxy collection install -r requirements.yml",
    "with-oslogin-ssh.py",
    "ansible-playbook",
    "loadgen.yml",
]:
    require(configure, token, "loadgen configuration entrypoint")

for forbidden in [
    "StrictHostKeyChecking=no",
    "enable_loadgen=true",
    "tofu apply",
    "gcloud compute instances create",
]:
    if forbidden in configure:
        raise SystemExit(f"configure-loadgen.sh must not mutate infrastructure or weaken SSH: {forbidden}")

for token in [
    "python3 scripts/workload/test-m8-loadgen-config.py",
    "bash -n deploy/m8-loadgen-preflight.sh deploy/configure-loadgen.sh",
    "loadgen.yml --syntax-check",
]:
    require(ci, token, "loadgen CI contract")

print("M8 Phase 3 loadgen configuration contract: PASS")
