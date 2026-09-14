#!/usr/bin/env bash
set -euo pipefail
umask 077

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

test "$(git rev-parse HEAD)" = "ce7c84832b4bbe55c8db45a3cb6219fb8183a611" || {
  echo "ERROR: configure-loadgen.sh must run from reviewed main ce7c84832b4bbe55c8db45a3cb6219fb8183a611" >&2
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
"$root/deploy/with-oslogin-ssh.py" --   ansible-playbook   --inventory "$inventory_file"   loadgen.yml   --extra-vars "k6_version=$K6_VERSION"   --extra-vars "k6_linux_amd64_deb_sha256=$K6_LINUX_AMD64_DEB_SHA256"
