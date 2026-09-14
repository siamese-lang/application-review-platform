#!/usr/bin/env bash
set -euo pipefail
umask 077

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
readonly PROFILE="${ARP_M8_DATASET_PROFILE:-M}"
readonly SEED=20260914

case "$PROFILE" in
  S|M) ;;
  *)
    echo "ERROR: ARP_M8_DATASET_PROFILE must be S or M for live M8 workload preparation." >&2
    exit 1
    ;;
esac

: "${ARP_EXPECTED_SOURCE_SHA:?Set ARP_EXPECTED_SOURCE_SHA to the reviewed 40-character main SHA}"
[[ $ARP_EXPECTED_SOURCE_SHA =~ ^[0-9a-f]{40}$ ]] || {
  echo "ERROR: ARP_EXPECTED_SOURCE_SHA must be a 40-character lowercase Git SHA." >&2
  exit 1
}
actual_sha=$(git -C "$root" rev-parse HEAD)
[[ $actual_sha == "$ARP_EXPECTED_SOURCE_SHA" ]] || {
  echo "ERROR: expected reviewed source $ARP_EXPECTED_SOURCE_SHA but checkout is $actual_sha" >&2
  exit 1
}

: "${ARP_CONFIRM_M8_DATASET_RESET:?Set ARP_CONFIRM_M8_DATASET_RESET=yes for the guarded M8 namespace reset/load}"
[[ $ARP_CONFIRM_M8_DATASET_RESET == yes ]] || {
  echo "ERROR: ARP_CONFIRM_M8_DATASET_RESET must equal yes." >&2
  exit 1
}

for command in python3 tar tofu ssh sudo; do
  command -v "$command" >/dev/null || {
    echo "Missing prerequisite: $command" >&2
    exit 1
  }
done

if [[ -z ${ARP_OSLOGIN_USER:-} || -z ${ARP_OSLOGIN_SSH_KEY:-} || -z ${ARP_OSLOGIN_KNOWN_HOSTS:-} ]]; then
  bundle_dir=$(mktemp -d /tmp/arp-m8-dataset-${PROFILE}.XXXXXX)
  trap 'rm -rf "$bundle_dir"' EXIT

  python3 "$root/scripts/workload/generate-synthetic-dataset.py"     --profile "$PROFILE"     --seed "$SEED"     --output "$bundle_dir"

  python3 - "$bundle_dir/dataset-manifest.json" "$PROFILE" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
profile = sys.argv[2]
manifest_bytes = manifest_path.read_bytes()
manifest = json.loads(manifest_bytes)
expected_by_profile = {
    "S": {
        "profile": "S",
        "seed": 20260914,
        "applications": 10000,
        "application_status_history": 39990,
        "audit_events": 49990,
        "users": 112,
        "programs": 12,
    },
    "M": {
        "profile": "M",
        "seed": 20260914,
        "applications": 100000,
        "application_status_history": 399990,
        "audit_events": 499990,
        "users": 1048,
        "programs": 12,
    },
}
expected = expected_by_profile[profile]
actual = {
    "profile": manifest.get("profile"),
    "seed": manifest.get("seed"),
    "applications": manifest.get("counts", {}).get("applications"),
    "application_status_history": manifest.get("counts", {}).get("application_status_history"),
    "audit_events": manifest.get("counts", {}).get("audit_events"),
    "users": manifest.get("counts", {}).get("users"),
    "programs": manifest.get("counts", {}).get("programs"),
}
if actual != expected:
    raise SystemExit(f"Unexpected generated {profile} manifest: {actual!r}")
if manifest.get("bulk_users_login_enabled") is not False:
    raise SystemExit("M8 bulk users must remain non-login fixtures")
if manifest.get("attachments_seeded") is not False:
    raise SystemExit("M8 bulk datasets must not claim attachment objects were seeded")
manifest_sha256 = hashlib.sha256(manifest_bytes).hexdigest()
print(
    "M8_DATASET_MANIFEST_OK "
    f"profile={profile} seed=20260914 "
    f"applications={expected['applications']} "
    f"histories={expected['application_status_history']} "
    f"audits={expected['audit_events']} "
    f"users={expected['users']} programs={expected['programs']} "
    f"manifest_sha256={manifest_sha256}"
)
PY

  export ARP_M8_DATASET_BUNDLE="$bundle_dir"
  "$root/deploy/with-oslogin-ssh.py" --ttl-seconds 3600 --     bash "$root/deploy/load-m8-dataset.sh"
  exit $?
fi

: "${ARP_M8_DATASET_BUNDLE:?Internal M8 dataset bundle path is missing}"
[[ -d $ARP_M8_DATASET_BUNDLE ]] || {
  echo "ERROR: generated M8 dataset bundle directory is unavailable." >&2
  exit 1
}

tofu_cmd=(tofu)
if [[ $EUID -ne 0 ]]; then
  tofu_cmd=(sudo -n tofu)
fi

db_ip=$(
  "${tofu_cmd[@]}" -chdir="$root/infra/opentofu" output -json inventory |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["db-01"]["private_ip"])'
)

python3 - "$db_ip" <<'PY'
import ipaddress
import sys

ip = ipaddress.ip_address(sys.argv[1])
if ip.version != 4 or not ip.is_private:
    raise SystemExit(f"db-01 inventory address is not a private IPv4 address: {ip}")
PY

ssh_cmd=(
  ssh
  -i "$ARP_OSLOGIN_SSH_KEY"
  -o "UserKnownHostsFile=$ARP_OSLOGIN_KNOWN_HOSTS"
  -o StrictHostKeyChecking=yes
  -o IdentitiesOnly=yes
  "$ARP_OSLOGIN_USER@$db_ip"
)

remote_dir=$("${ssh_cmd[@]}" sudo -u postgres mktemp -d /tmp/arp-m8-dataset-${PROFILE}.XXXXXX)
[[ $remote_dir == /tmp/arp-m8-dataset-${PROFILE}.* ]] || {
  echo "ERROR: unexpected remote dataset directory: $remote_dir" >&2
  exit 1
}

cleanup_remote() {
  "${ssh_cmd[@]}" sudo rm -rf -- "$remote_dir" >/dev/null 2>&1 || true
}
trap cleanup_remote EXIT

tar -C "$ARP_M8_DATASET_BUNDLE" -cf - . |
  "${ssh_cmd[@]}" "sudo -u postgres tar -xf - -C '$remote_dir'"

"${ssh_cmd[@]}" "sudo -u postgres bash -s -- '$remote_dir'" <<'REMOTE'
set -euo pipefail
bundle_dir=$1
cd "$bundle_dir"

psql -d arp   -v ON_ERROR_STOP=1   -v m8_confirm_synthetic_reset=true   -f load.sql

psql -d arp   -v ON_ERROR_STOP=1   -f verify.sql

psql -d arp   -v ON_ERROR_STOP=1   --tuples-only   --no-align <<'SQL'
SELECT 'applications=' || count(*) FROM applications WHERE id BETWEEN 8200000001 AND 8299999999;
SELECT 'histories=' || count(*) FROM application_status_history WHERE id BETWEEN 8300000001 AND 8399999999;
SELECT 'audits=' || count(*) FROM audit_events WHERE id BETWEEN 8400000001 AND 8499999999;
SELECT 'users=' || count(*) FROM users WHERE id BETWEEN 8100000001 AND 8199999999;
SELECT 'programs=' || count(*) FROM programs WHERE id BETWEEN 8000000001 AND 8099999999;
SQL
REMOTE

echo "PASS: M8 dataset $PROFILE generated, guarded-load applied, and generated invariants verified."
