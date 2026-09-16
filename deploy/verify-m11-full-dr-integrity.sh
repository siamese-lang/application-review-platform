#!/usr/bin/env bash
set -euo pipefail
umask 077

checkpoint_id=${1:-}
manifest_sha256=${2:-}
checkpoint_cutoff=${3:-}
expected_checkpoint_available=${4:-}

if [[ ! $checkpoint_id =~ ^[A-Za-z0-9._-]+$ || ${#checkpoint_id} -gt 80 ]]; then
  echo "usage: $0 <checkpoint-id> <manifest-sha256> <checkpoint-cutoff> <expected-available-count>" >&2
  exit 2
fi
if [[ ! $manifest_sha256 =~ ^[0-9a-f]{64}$ ]]; then
  echo "manifest SHA-256 must be 64 lowercase hex characters" >&2
  exit 2
fi
if [[ ! $checkpoint_cutoff =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]; then
  echo "checkpoint cutoff must be an ISO-8601 timestamp" >&2
  exit 2
fi
if [[ ! $expected_checkpoint_available =~ ^[1-9][0-9]*$ ]]; then
  echo "expected available attachment count must be a positive integer" >&2
  exit 2
fi

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${SOPS_AGE_KEY_FILE:?Point to the age private key outside the repository on ops-01}"
: "${ARP_SECRETS_FILE:?Point to committed SOPS-encrypted runtime YAML}"

tofu_cmd=(tofu)
if [[ $EUID -ne 0 ]]; then
  tofu_cmd=(sudo -n tofu)
fi

full_dr_json=$("${tofu_cmd[@]}" -chdir="$root/infra/opentofu" output -json full_dr_inventory)
backup_json=$("${tofu_cmd[@]}" -chdir="$root/infra/opentofu" output -json backup)

inventory_json=$(python3 - "$full_dr_json" "$backup_json" <<'PY'
import json
import sys

full_dr = json.loads(sys.argv[1])
backup = json.loads(sys.argv[2])
expected = {
    "dr-edge-01",
    "dr-app-01",
    "dr-db-01",
    "dr-storage-01",
    "dr-storage-02",
    "dr-storage-03",
}
if set(full_dr) != expected:
    raise SystemExit(f"unexpected full DR inventory: {sorted(full_dr)}")
if not backup or backup.get("private_ip") != "10.60.0.10":
    raise SystemExit("backup-01 output is missing or unexpected")
full_dr["backup-01"] = {
    "role": "backup",
    "zone": backup["zone"],
    "private_ip": backup["private_ip"],
}
print(json.dumps(full_dr))
PY
)

inventory_file=$(mktemp /tmp/m11-full-dr-integrity.XXXXXX.yml)
secret_vars=$(mktemp /tmp/m11-full-dr-integrity-secrets.XXXXXX.yml)
trap 'rm -f "$inventory_file" "$secret_vars"' EXIT

printf '%s\n' "$inventory_json" | "$root/deploy/generate-inventory.py" >"$inventory_file"
sops --decrypt "$ARP_SECRETS_FILE" >"$secret_vars"

cd "$root/config/ansible"
"$root/deploy/with-oslogin-ssh.py" -- ansible-playbook   --inventory "$inventory_file"   full-dr-integrity.yml   --extra-vars "@$secret_vars"   --extra-vars "m11_checkpoint_id=$checkpoint_id"   --extra-vars "m11_manifest_sha256=$manifest_sha256"   --extra-vars "m11_checkpoint_cutoff=$checkpoint_cutoff"   --extra-vars "m11_expected_checkpoint_available=$expected_checkpoint_available"
