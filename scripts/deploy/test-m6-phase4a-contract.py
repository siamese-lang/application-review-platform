#!/usr/bin/env python3
"""Offline contract checks for M6 Phase 4A tooling."""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
preflight = (ROOT / "deploy/m6-runtime-preflight.sh").read_text()
users = (ROOT / "deploy/bootstrap-synthetic-users.sh").read_text()
bootstrap = (ROOT / "deploy/tofu-bootstrap-plan.sh").read_text()
runtime = (ROOT / "deploy/tofu-init-plan.sh").read_text()
prepare_secrets = (ROOT / "deploy/prepare-secrets.sh").read_text()
configure_runtime = (ROOT / "deploy/configure-runtime.sh").read_text()

assert "PROJECT_ID=application-review-platform" in preflight
assert "REGION=asia-northeast3" in preflight
for api in ("compute", "iam", "iamcredentials", "sts", "iap", "oslogin", "cloudresourcemanager", "serviceusage"):
    assert f"{api}.googleapis.com" in preflight
for node in ("edge-01", "app-01", "db-01", "storage-01", "storage-02", "storage-03", "ops-01"):
    assert node in preflight
for check in ("billing projects describe", "services list --enabled", "project-info describe", "regions describe"):
    assert check in preflight

mutating = re.compile(r"\bgcloud\s+(?:[^\n]*\s)?(?:create|delete|update|add-iam-policy-binding|remove-iam-policy-binding|enable|disable|set)\b")
assert not mutating.search(preflight), "preflight contains a mutating gcloud command"

insert = re.search(r'printf "(INSERT INTO users .*?)\\n"', users, re.DOTALL)
assert insert
columns = {c.strip() for c in re.search(r"users \(([^)]+)\)", insert.group(1)).group(1).split(",")}
assert columns == {"username", "password_hash", "role", "display_name", "email", "created_at", "updated_at"}
assert all(identity in users for identity in ("m6-${role,,}", "@example.test", "CURRENT_TIMESTAMP"))
assert "WHERE NOT EXISTS" in users and "htpasswd -bnBC 12" in users
assert "echo \"$password\"" not in users and "echo \"$hash\"" not in users
assert "Flyway V5 schema" in users
assert "required_column_count <> 7" in users
assert "DO $$" in users
assert "END $$;" in users
assert 'root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)' in users
assert "git rev-parse --show-toplevel" not in users

for text, variable in ((bootstrap, "ARP_BOOTSTRAP_STATE_PATH"), (runtime, "ARP_TOFU_STATE_PATH")):
    assert f"${{{variable}:?" in text
    assert "outside the Git checkout" in text
assert "google_service_account.ops" in bootstrap and "google_service_account.workload" in bootstrap
assert 'root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)' in prepare_secrets
assert 'root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)' in configure_runtime
assert "git rev-parse --show-toplevel" not in prepare_secrets
assert "git rev-parse --show-toplevel" not in configure_runtime

phase4_tools = preflight + bootstrap + runtime + users
assert "deploy-release.sh" not in phase4_tools and "rollback-release.sh" not in phase4_tools

tracked = subprocess.check_output(["git", "ls-files"], cwd=ROOT, text=True).splitlines()
for name in tracked:
    assert not re.search(r"(?:\.tfstate(?:\.|$)|\.tfplan$|\.agekey$|\.dec\.ya?ml$)", name), name
print("M6 Phase 4A offline contracts: PASS")

assert "DO $\n" not in users
assert "END $;\n" not in users