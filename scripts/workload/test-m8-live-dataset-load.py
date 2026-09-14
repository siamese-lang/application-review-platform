#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
script = (ROOT / "deploy/load-m8-dataset.sh").read_text(encoding="utf-8")


def require(token: str) -> None:
    if token not in script:
        raise SystemExit(f"missing live M dataset loader contract: {token}")


for token in [
    "readonly PROFILE=M",
    "readonly SEED=20260914",
    "ARP_EXPECTED_SOURCE_SHA",
    "ARP_CONFIRM_M8_DATASET_RESET",
    "ARP_CONFIRM_M8_DATASET_RESET == yes",
    "generate-synthetic-dataset.py",
    "--profile \"$PROFILE\"",
    "--seed \"$SEED\"",
    "applications=100000",
    "histories=399990",
    "audits=499990",
    "users=1048",
    "programs=12",
    "manifest_sha256=",
    "with-oslogin-ssh.py",
    "--ttl-seconds 3600",
    'bash "$root/deploy/load-m8-dataset.sh"',
    'json.load(sys.stdin)["db-01"]["private_ip"]',
    "StrictHostKeyChecking=yes",
    "sudo -u postgres mktemp -d /tmp/arp-m8-dataset-M.",
    "m8_confirm_synthetic_reset=true",
    "-f load.sql",
    "-f verify.sql",
    "PASS: M8 dataset M generated, guarded-load applied, and generated invariants verified.",
]:
    require(token)

for forbidden in [
    "PGPASSWORD=",
    "DB_PASSWORD",
    "StrictHostKeyChecking=no",
    "enable_loadgen=true",
    "tofu apply",
]:
    if forbidden in script:
        raise SystemExit(f"live M dataset loader must not contain: {forbidden}")

generate_pos = script.index("generate-synthetic-dataset.py")
oslogin_pos = script.index("with-oslogin-ssh.py")
if generate_pos > oslogin_pos:
    raise SystemExit("dataset M must be generated before the ephemeral OS Login key is requested")

print("M8 Phase 3 live dataset loader contract: PASS")
