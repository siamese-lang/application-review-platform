#!/usr/bin/env bash
set -euo pipefail
umask 077

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${SOPS_AGE_KEY_FILE:?Point to the age private key outside the repository on ops-01}"
: "${ARP_SECRETS_FILE:?Point to committed SOPS-encrypted runtime YAML}"

if [[ -n ${ARP_TLS_CERTIFICATE:-} || -n ${ARP_TLS_PRIVATE_KEY:-} ]]; then
  : "${ARP_TLS_CERTIFICATE:?Set both ARP_TLS_CERTIFICATE and ARP_TLS_PRIVATE_KEY}"
  : "${ARP_TLS_PRIVATE_KEY:?Set both ARP_TLS_CERTIFICATE and ARP_TLS_PRIVATE_KEY}"
fi

tofu_cmd=(tofu)
if [[ $EUID -ne 0 ]]; then
  tofu_cmd=(sudo -n tofu)
fi

runtime_root="$root/infra/opentofu"
full_dr_json=$("${tofu_cmd[@]}" -chdir="$runtime_root" output -json full_dr_inventory)
backup_json=$("${tofu_cmd[@]}" -chdir="$runtime_root" output -json backup)

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

inventory_file=$(mktemp /tmp/m11-full-dr-inventory.XXXXXX.yml)
secret_vars=$(mktemp /tmp/m11-full-dr-secrets.XXXXXX.yml)
trap 'rm -f "$inventory_file" "$secret_vars"' EXIT

printf '%s\n' "$inventory_json" | "$root/deploy/generate-inventory.py" >"$inventory_file"
sops --decrypt "$ARP_SECRETS_FILE" >"$secret_vars"

cd "$root/config/ansible"
ansible-galaxy collection install -r requirements.yml
"$root/deploy/with-oslogin-ssh.py" -- ansible-playbook   --inventory "$inventory_file"   full-dr-foundation.yml   --extra-vars "@$secret_vars"
