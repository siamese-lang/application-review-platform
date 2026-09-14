#!/usr/bin/env bash
set -euo pipefail
umask 077

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

: "${ARP_EXPECTED_SOURCE_SHA:?Set ARP_EXPECTED_SOURCE_SHA to the reviewed 40-character main SHA}"
[[ $ARP_EXPECTED_SOURCE_SHA =~ ^[0-9a-f]{40}$ ]] || {
  echo "ERROR: ARP_EXPECTED_SOURCE_SHA must be a 40-character lowercase Git SHA." >&2
  exit 1
}
actual_sha=$(git rev-parse HEAD)
[[ $actual_sha == "$ARP_EXPECTED_SOURCE_SHA" ]] || {
  echo "ERROR: expected reviewed source $ARP_EXPECTED_SOURCE_SHA but checkout is $actual_sha" >&2
  exit 1
}

# shellcheck disable=SC1091
source "$root/workload/tool-versions.env"
: "${K6_VERSION:?Missing K6_VERSION in workload/tool-versions.env}"
: "${K6_LINUX_AMD64_DEB_SHA256:?Missing k6 checksum in workload/tool-versions.env}"

loadgen_json=$(tofu -chdir="$root/infra/opentofu" output -json loadgen)
inventory_file=$(mktemp)
trap 'rm -f "$inventory_file"' EXIT

python3 - "$loadgen_json" >"$inventory_file" <<'PY'
import json
import sys

loadgen = json.loads(sys.argv[1])
expected = {
    "name": "loadgen-01",
    "private_ip": "10.50.0.10",
    "region": "asia-northeast1",
    "zone": "asia-northeast1-a",
}
if loadgen != expected:
    raise SystemExit(f"Unexpected loadgen output: {loadgen!r}")

print("---")
print("all:")
print("  children:")
print("    loadgen:")
print("      hosts:")
print("        loadgen-01:")
print(f"          ansible_host: {loadgen['private_ip']}")
print(f"          garage_zone: {loadgen['zone']}")
PY

cd "$root/config/ansible"
ansible-galaxy collection install -r requirements.yml
"$root/deploy/with-oslogin-ssh.py" --   ansible-playbook   --inventory "$inventory_file"   loadgen.yml   --extra-vars "k6_version=$K6_VERSION"   --extra-vars "k6_linux_amd64_deb_sha256=$K6_LINUX_AMD64_DEB_SHA256"
