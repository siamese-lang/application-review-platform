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

: "${SYNTHETIC_APPLICANT_PASSWORD:?Load the controlled m6-applicant password into SYNTHETIC_APPLICANT_PASSWORD}"
: "${SYNTHETIC_REVIEWER_PASSWORD:?Load the controlled m6-reviewer password into SYNTHETIC_REVIEWER_PASSWORD}"

if [[ $SYNTHETIC_APPLICANT_PASSWORD == *$'\n'* || $SYNTHETIC_REVIEWER_PASSWORD == *$'\n'* ]]; then
  echo "ERROR: synthetic workload passwords must not contain newlines." >&2
  exit 1
fi

if [[ -z ${ARP_OSLOGIN_USER:-} || -z ${ARP_OSLOGIN_SSH_KEY:-} || -z ${ARP_OSLOGIN_KNOWN_HOSTS:-} ]]; then
  : "${ARP_CONFIRM_M8_DATASET_RESET:?Set ARP_CONFIRM_M8_DATASET_RESET=yes so W1 can load dataset S}"
  [[ $ARP_CONFIRM_M8_DATASET_RESET == yes ]] || {
    echo "ERROR: ARP_CONFIRM_M8_DATASET_RESET must equal yes." >&2
    exit 1
  }

  dataset_log=$(mktemp)
  trap 'rm -f "$dataset_log"' EXIT

  ARP_M8_DATASET_PROFILE=S     bash "$root/deploy/load-m8-dataset.sh" |
    tee "$dataset_log"

  dataset_manifest_sha=$(
    python3 - "$dataset_log" <<'PY'
import re
import sys

text = open(sys.argv[1], encoding="utf-8").read()
match = re.search(
    r"M8_DATASET_MANIFEST_OK profile=S seed=20260914 .*manifest_sha256=([0-9a-f]{64})",
    text,
)
if not match:
    raise SystemExit("W1 could not capture the verified dataset S manifest SHA-256")
print(match.group(1))
PY
  )

  rm -f "$dataset_log"
  trap - EXIT

  export ARP_M8_W1_DATASET_READY=yes
  export ARP_M8_W1_DATASET_MANIFEST_SHA="$dataset_manifest_sha"

  exec "$root/deploy/with-oslogin-ssh.py"     --ttl-seconds 1800     -- bash "$root/workload/run-w1.sh"
fi

[[ ${ARP_M8_W1_DATASET_READY:-} == yes ]] || {
  echo "ERROR: W1 must enter the trusted SSH phase only after dataset S verification." >&2
  exit 1
}
[[ ${ARP_M8_W1_DATASET_MANIFEST_SHA:-} =~ ^[0-9a-f]{64}$ ]] || {
  echo "ERROR: verified dataset S manifest SHA-256 is missing." >&2
  exit 1
}

for command in python3 tar tofu ssh sudo sha256sum date; do
  command -v "$command" >/dev/null || {
    echo "Missing prerequisite: $command" >&2
    exit 1
  }
done

# shellcheck disable=SC1091
source "$root/workload/tool-versions.env"
: "${K6_VERSION:?Missing K6_VERSION in workload/tool-versions.env}"

tofu_cmd=(tofu)
if [[ $EUID -ne 0 ]]; then
  tofu_cmd=(sudo -n tofu)
fi

loadgen_json=$("${tofu_cmd[@]}" -chdir="$root/infra/opentofu" output -json loadgen)
inventory_json=$("${tofu_cmd[@]}" -chdir="$root/infra/opentofu" output -json inventory)
edge_public_ip=$("${tofu_cmd[@]}" -chdir="$root/infra/opentofu" output -raw edge_public_ip)

read -r loadgen_ip app_ip edge_private_ip < <(
  python3 - "$loadgen_json" "$inventory_json" <<'PY'
import ipaddress
import json
import sys

loadgen = json.loads(sys.argv[1])
inventory = json.loads(sys.argv[2])
expected = {
    "name": "loadgen-01",
    "region": "asia-northeast1",
    "zone": "asia-northeast1-a",
    "private_ip": "10.50.0.10",
}
if loadgen != expected:
    raise SystemExit(f"unexpected loadgen identity: {loadgen!r}")

values = [
    loadgen["private_ip"],
    inventory["app-01"]["private_ip"],
    inventory["edge-01"]["private_ip"],
]
for value in values:
    ip = ipaddress.ip_address(value)
    if ip.version != 4 or not ip.is_private:
        raise SystemExit(f"expected private IPv4 address, got {value}")
print(*values)
PY
)

python3 - "$edge_public_ip" <<'PY'
import ipaddress
import sys

ip = ipaddress.ip_address(sys.argv[1])
if ip.version != 4 or ip.is_private:
    raise SystemExit(f"edge_public_ip is not a public IPv4 address: {ip}")
PY

ssh_common=(
  ssh
  -i "$ARP_OSLOGIN_SSH_KEY"
  -o "UserKnownHostsFile=$ARP_OSLOGIN_KNOWN_HOSTS"
  -o StrictHostKeyChecking=yes
  -o IdentitiesOnly=yes
  -o ConnectTimeout=10
)

backend_state=$(
  "${ssh_common[@]}" "$ARP_OSLOGIN_USER@$app_ip"     sudo cat /opt/arp/release-state/backend.json
)
frontend_state=$(
  "${ssh_common[@]}" "$ARP_OSLOGIN_USER@$edge_private_ip"     sudo cat /opt/arp/release-state/frontend.json
)

read -r backend_release_sha frontend_release_sha < <(
  python3 - "$backend_state" "$frontend_state" <<'PY'
import json
import re
import sys

backend = json.loads(sys.argv[1])
frontend = json.loads(sys.argv[2])
backend_sha = backend.get("current")
frontend_sha = frontend.get("current")
pattern = re.compile(r"^[0-9a-f]{40}$")
if not isinstance(backend_sha, str) or not pattern.fullmatch(backend_sha):
    raise SystemExit(f"invalid backend release state: {backend!r}")
if not isinstance(frontend_sha, str) or not pattern.fullmatch(frontend_sha):
    raise SystemExit(f"invalid frontend release state: {frontend!r}")
print(backend_sha, frontend_sha)
PY
)

release_sha="$backend_release_sha"

base_url="https://$edge_public_ip"
run_id="m8-w1-$(date -u +%Y%m%dT%H%M%SZ)-${actual_sha:0:8}"
run_dir="$root/build/workload/runs/$run_id"
mkdir -p "$run_dir"

fixture="$root/workload/fixtures/w1-attachment.txt"
fixture_sha=$(sha256sum "$fixture" | awk '{print $1}')

ssh_loadgen=("${ssh_common[@]}" "$ARP_OSLOGIN_USER@$loadgen_ip")
remote_dir=$("${ssh_loadgen[@]}" mktemp -d /tmp/arp-m8-w1.XXXXXX)
[[ $remote_dir == /tmp/arp-m8-w1.* ]] || {
  echo "ERROR: unexpected loadgen temporary directory: $remote_dir" >&2
  exit 1
}

cleanup_remote() {
  "${ssh_loadgen[@]}" rm -rf -- "$remote_dir" >/dev/null 2>&1 || true
}
trap cleanup_remote EXIT

tar -C "$root/workload" -cf -   k6/w1-smoke.js   fixtures/w1-attachment.txt |
  "${ssh_loadgen[@]}" "tar -xf - -C '$remote_dir'"

remote_k6_version=$("${ssh_loadgen[@]}" k6 version)
[[ $remote_k6_version == *"k6 v$K6_VERSION"* ]] || {
  echo "ERROR: loadgen k6 version does not match the repository pin: $remote_k6_version" >&2
  exit 1
}

started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

remote_command="set -euo pipefail; IFS= read -r APPLICANT_PASSWORD; IFS= read -r REVIEWER_PASSWORD; export APPLICANT_PASSWORD REVIEWER_PASSWORD; cd '$remote_dir'; BASE_URL='$base_url' RUN_ID='$run_id' APPLICANT_USERNAME='m6-applicant' REVIEWER_USERNAME='m6-reviewer' ATTACHMENT_PATH='../fixtures/w1-attachment.txt' THINK_TIME_SECONDS='0.2' k6 run --summary-export summary.json k6/w1-smoke.js"

{
  printf '%s\n' "$SYNTHETIC_APPLICANT_PASSWORD"
  printf '%s\n' "$SYNTHETIC_REVIEWER_PASSWORD"
} |
  "${ssh_loadgen[@]}" "$remote_command" |
  tee "$run_dir/k6-output.txt"

"${ssh_loadgen[@]}" "cat '$remote_dir/summary.json'" > "$run_dir/k6-summary.json"
finished_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

python3 -   "$run_dir/run-manifest.json"   "$run_id"   "$actual_sha"   "$release_sha"   "$backend_release_sha"   "$frontend_release_sha"   "$ARP_M8_W1_DATASET_MANIFEST_SHA"   "$K6_VERSION"   "$started_at"   "$finished_at"   "$fixture_sha" <<'PY'
import json
import sys

(
    output,
    run_id,
    source_sha,
    release_sha,
    backend_release_sha,
    frontend_release_sha,
    dataset_manifest_sha,
    k6_version,
    started_at,
    finished_at,
    fixture_sha,
) = sys.argv[1:]

manifest = {
    "schema_version": 1,
    "run_id": run_id,
    "source_sha": source_sha,
    "release_sha": release_sha,
    "dataset": {
        "name": "S",
        "seed": 20260914,
        "manifest_version": f"sha256:{dataset_manifest_sha}",
    },
    "loadgen": {
        "region": "asia-northeast1",
        "zone": "asia-northeast1-a",
        "machine_type": "e2-standard-2",
        "k6_version": k6_version,
    },
    "workload": {
        "scenario": "w1-business-smoke",
        "version": "1",
        "vus": 1,
        "duration": "per-vu-iterations:1,maxDuration:2m",
        "think_time_seconds": 0.2,
        "attachment_fixture": f"w1-attachment.txt sha256:{fixture_sha}",
    },
    "runtime": {
        "project_id": "application-review-platform",
        "primary_region": "asia-northeast3",
        "persistent_nodes": [
            "edge-01",
            "app-01",
            "db-01",
            "storage-01",
            "storage-02",
            "storage-03",
            "ops-01",
            "obs-01",
        ],
        "component_releases": {
            "backend": backend_release_sha,
            "frontend": frontend_release_sha,
        },
    },
    "started_at": started_at,
    "finished_at": finished_at,
}

with open(output, "w", encoding="utf-8") as handle:
    json.dump(manifest, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY

python3 - "$run_dir/k6-summary.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
metrics = data.get("metrics", {})
required = ["checks", "http_req_failed", "http_req_duration", "http_reqs"]
missing = [name for name in required if name not in metrics]
if missing:
    raise SystemExit(f"W1 k6 summary is missing required metrics: {missing}")
PY

echo "W1_RUN_ID=$run_id"
echo "W1_SOURCE_SHA=$actual_sha"
echo "W1_RELEASE_SHA=$release_sha"
echo "W1_BACKEND_RELEASE_SHA=$backend_release_sha"
echo "W1_FRONTEND_RELEASE_SHA=$frontend_release_sha"
echo "W1_DATASET_MANIFEST_SHA256=$ARP_M8_W1_DATASET_MANIFEST_SHA"
echo "W1_ARTIFACT_DIR=$run_dir"
echo "PASS: M8 W1 exercised list/detail, create/save, submit/resubmit, reviewer queue/detail, review actions, and attachment upload/download through the real deployed boundary."
