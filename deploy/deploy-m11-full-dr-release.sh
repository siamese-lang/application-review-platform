#!/usr/bin/env bash
set -euo pipefail
umask 077

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${ARP_RELEASE_BUNDLE_DIR:?Set the exact local release bundle directory on ops-01}"
: "${ARP_RELEASE_SHA:?Set the full lowercase 40-character release source SHA}"
: "${ARP_RUNTIME_SECRETS_FILE:?Set a decrypted runtime secrets YAML file on ops-01}"

[[ $ARP_RELEASE_SHA =~ ^[0-9a-f]{40}$ ]] || {
  echo 'ARP_RELEASE_SHA must be a full lowercase 40-character Git SHA.' >&2
  exit 1
}

bundle_dir=$(realpath "$ARP_RELEASE_BUNDLE_DIR")
runtime_secrets=$(realpath "$ARP_RUNTIME_SECRETS_FILE")
[[ -f $runtime_secrets ]] || {
  echo 'ARP_RUNTIME_SECRETS_FILE must be a regular file.' >&2
  exit 1
}

bash "$root/scripts/release/verify-release-bundle.sh" "$bundle_dir" "$ARP_RELEASE_SHA"

tofu_cmd=(tofu)
if [[ $EUID -ne 0 ]]; then
  tofu_cmd=(sudo -n tofu)
fi

full_dr_json=$("${tofu_cmd[@]}" -chdir="$root/infra/opentofu" output -json full_dr_inventory)
inventory_file=$(mktemp /tmp/m11-full-dr-release.XXXXXX.yml)
release_vars=$(mktemp /tmp/m11-full-dr-release-vars.XXXXXX.json)
trap 'rm -f "$inventory_file" "$release_vars"' EXIT

python3 - "$full_dr_json" <<'PY' | "$root/deploy/generate-inventory.py" >"$inventory_file"
import json
import sys

full_dr = json.loads(sys.argv[1])
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
print(json.dumps(full_dr))
PY

python3 - "$bundle_dir" "$ARP_RELEASE_SHA" >"$release_vars" <<'PY'
import json
import sys

json.dump(
    {"arp_release_bundle_dir": sys.argv[1], "arp_release_sha": sys.argv[2]},
    sys.stdout,
)
PY

cd "$root/config/ansible"
"$root/deploy/with-oslogin-ssh.py" -- ansible-playbook   --inventory "$inventory_file"   release.yml   --extra-vars "@$release_vars"   --extra-vars "@$runtime_secrets"
