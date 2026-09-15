#!/usr/bin/env bash
set -euo pipefail
umask 077

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
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

: "${SYNTHETIC_APPLICANT_PASSWORD:?Load the controlled m6-applicant password}"
: "${SYNTHETIC_REVIEWER_PASSWORD:?Load the controlled m6-reviewer password}"

if [[ $SYNTHETIC_APPLICANT_PASSWORD == *$'\n'* || $SYNTHETIC_REVIEWER_PASSWORD == *$'\n'* ]]; then
  echo "ERROR: synthetic reliability passwords must not contain newlines." >&2
  exit 1
fi

if [[ -z ${ARP_OSLOGIN_USER:-} || -z ${ARP_OSLOGIN_SSH_KEY:-} || -z ${ARP_OSLOGIN_KNOWN_HOSTS:-} ]]; then
  : "${ARP_CONFIRM_M10_DATASET_RESET:?Set ARP_CONFIRM_M10_DATASET_RESET=yes for the guarded healthy-control reset}"
  [[ $ARP_CONFIRM_M10_DATASET_RESET == yes ]] || {
    echo "ERROR: ARP_CONFIRM_M10_DATASET_RESET must equal yes." >&2
    exit 1
  }

  dataset_log=$(mktemp)
  trap 'rm -f "$dataset_log"' EXIT

  ARP_CONFIRM_M8_DATASET_RESET=yes \
  ARP_M8_DATASET_PROFILE=M \
    bash "$root/deploy/load-m8-dataset.sh" | tee "$dataset_log"

  dataset_manifest_sha=$(
    python3 - "$dataset_log" <<'PY'
import re
import sys

text = open(sys.argv[1], encoding="utf-8").read()
match = re.search(
    r"M8_DATASET_MANIFEST_OK profile=M seed=20260914 .*manifest_sha256=([0-9a-f]{64})",
    text,
)
if not match:
    raise SystemExit("M10 control could not capture dataset M manifest SHA-256")
print(match.group(1))
PY
  )

  rm -f "$dataset_log"
  trap - EXIT

  export ARP_M10_DATASET_READY=yes
  export ARP_M10_DATASET_MANIFEST_SHA="$dataset_manifest_sha"

  exec "$root/deploy/with-oslogin-ssh.py" \
    --ttl-seconds 1800 \
    -- bash "$root/scripts/reliability/run-m10-control.sh"
fi

[[ ${ARP_M10_DATASET_READY:-} == yes ]] || {
  echo "ERROR: M10 control must enter trusted SSH phase after dataset verification." >&2
  exit 1
}
[[ ${ARP_M10_DATASET_MANIFEST_SHA:-} =~ ^[0-9a-f]{64}$ ]] || {
  echo "ERROR: M10 verified dataset manifest SHA-256 is missing." >&2
  exit 1
}

for command in python3 tar tofu ssh sha256sum date; do
  command -v "$command" >/dev/null || {
    echo "ERROR: missing prerequisite: $command" >&2
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

if ! loadgen_json=$("${tofu_cmd[@]}" -chdir="$root/infra/opentofu" output -json loadgen 2>/dev/null); then
  echo "ERROR: temporary loadgen output is absent. Recreate the reviewed existing loadgen topology before running M10 control." >&2
  exit 2
fi

inventory_json=$("${tofu_cmd[@]}" -chdir="$root/infra/opentofu" output -json inventory)
edge_public_ip=$("${tofu_cmd[@]}" -chdir="$root/infra/opentofu" output -raw edge_public_ip)

read -r loadgen_ip app_ip edge_private_ip db_ip obs_ip < <(
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
    inventory["db-01"]["private_ip"],
    inventory["obs-01"]["private_ip"],
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
    raise SystemExit(f"edge_public_ip is not public IPv4: {ip}")
PY

ssh_common=(
  ssh
  -i "$ARP_OSLOGIN_SSH_KEY"
  -o "UserKnownHostsFile=$ARP_OSLOGIN_KNOWN_HOSTS"
  -o StrictHostKeyChecking=yes
  -o IdentitiesOnly=yes
  -o ConnectTimeout=10
)
ssh_db=("${ssh_common[@]}" "$ARP_OSLOGIN_USER@$db_ip")
ssh_loadgen=("${ssh_common[@]}" "$ARP_OSLOGIN_USER@$loadgen_ip")
ssh_obs=("${ssh_common[@]}" "$ARP_OSLOGIN_USER@$obs_ip")

overlay="$root/workload/sql/w2-interactive-overlay.sql"
overlay_sha=$(sha256sum "$overlay" | awk '{print $1}')

echo "STEP: apply deterministic normal-load interactive overlay"
cat "$overlay" |
  "${ssh_db[@]}" sudo -u postgres psql -d arp -v ON_ERROR_STOP=1 >/dev/null

backend_state=$(
  "${ssh_common[@]}" "$ARP_OSLOGIN_USER@$app_ip" sudo cat /opt/arp/release-state/backend.json
)
frontend_state=$(
  "${ssh_common[@]}" "$ARP_OSLOGIN_USER@$edge_private_ip" sudo cat /opt/arp/release-state/frontend.json
)

read -r backend_release_sha frontend_release_sha < <(
  python3 - "$backend_state" "$frontend_state" <<'PY'
import json
import re
import sys

states = [json.loads(sys.argv[1]), json.loads(sys.argv[2])]
values = [states[0].get("current"), states[1].get("current")]
pattern = re.compile(r"^[0-9a-f]{40}$")
if any(not isinstance(value, str) or not pattern.fullmatch(value) for value in values):
    raise SystemExit(f"invalid component release state: {states!r}")
print(*values)
PY
)

base_url="https://$edge_public_ip"
run_id="m10-control-$(date -u +%Y%m%dT%H%M%SZ)-${actual_sha:0:8}"
run_dir="$root/build/reliability/runs/$run_id"
mkdir -p "$run_dir"

fixture="$root/workload/fixtures/w1-attachment.txt"
fixture_sha=$(sha256sum "$fixture" | awk '{print $1}')

remote_dir=$("${ssh_loadgen[@]}" mktemp -d /tmp/arp-m10-control.XXXXXX)
[[ $remote_dir == /tmp/arp-m10-control.* ]] || {
  echo "ERROR: unexpected loadgen temporary directory: $remote_dir" >&2
  exit 1
}

cleanup_remote() {
  "${ssh_loadgen[@]}" rm -rf -- "$remote_dir" >/dev/null 2>&1 || true
}
trap cleanup_remote EXIT

tar -C "$root/workload" -cf - k6/m10-normal.js fixtures/w1-attachment.txt |
  "${ssh_loadgen[@]}" "tar -xf - -C '$remote_dir'"

remote_k6_version=$("${ssh_loadgen[@]}" k6 version)
[[ $remote_k6_version == *"k6 v$K6_VERSION"* ]] || {
  echo "ERROR: loadgen k6 version does not match repository pin: $remote_k6_version" >&2
  exit 1
}

started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

remote_command="set -euo pipefail; IFS= read -r APPLICANT_PASSWORD; IFS= read -r REVIEWER_PASSWORD; export APPLICANT_PASSWORD REVIEWER_PASSWORD; cd '$remote_dir'; BASE_URL='$base_url' RUN_ID='$run_id' M10_DURATION='5m' APPLICANT_USERNAME='m6-applicant' REVIEWER_USERNAME='m6-reviewer' ATTACHMENT_PATH='../fixtures/w1-attachment.txt' k6 run --summary-export summary.json k6/m10-normal.js"

echo "STEP: run M10 healthy normal-load control"
{
  printf '%s\n' "$SYNTHETIC_APPLICANT_PASSWORD"
  printf '%s\n' "$SYNTHETIC_REVIEWER_PASSWORD"
} |
  "${ssh_loadgen[@]}" "$remote_command" |
  tee "$run_dir/k6-output.txt"

"${ssh_loadgen[@]}" "cat '$remote_dir/summary.json'" > "$run_dir/k6-summary.json"

echo "STEP: post-control HTTPS business smoke"
BASE_URL="$base_url" \
REVIEWER_USERNAME=m6-reviewer \
REVIEWER_PASSWORD="$SYNTHETIC_REVIEWER_PASSWORD" \
ATTACHMENT_FIXTURE="$fixture" \
  bash "$root/deploy/cloud-smoke.sh" |
  tee "$run_dir/cloud-smoke.txt"

echo "STEP: retain database business invariants"
cat "$root/scripts/reliability/m10-db-invariants.sql" |
  "${ssh_db[@]}" sudo -u postgres psql -d arp -v ON_ERROR_STOP=1 \
  > "$run_dir/db-invariants.txt"

python3 - "$run_dir/db-invariants.txt" <<'PY'
import sys

required_zero = {
    "non_draft_latest_history_mismatch",
    "in_review_without_reviewer",
    "audit_subject_count_violation",
    "available_attachment_metadata_incomplete",
}
values = {}
for raw in open(sys.argv[1], encoding="utf-8"):
    raw = raw.strip()
    if not raw or "|" not in raw:
        continue
    key, value = raw.split("|", 1)
    try:
        values[key] = int(value)
    except ValueError:
        continue

missing = required_zero - values.keys()
bad = {key: values[key] for key in required_zero if values.get(key) != 0}
if missing:
    raise SystemExit(f"missing invariant rows: {sorted(missing)}")
if bad:
    raise SystemExit(f"business invariant violations: {bad}")

for key in sorted(values):
    print(f"M10_INVARIANT_{key.upper()}={values[key]}")
print("M10_DB_INVARIANTS=PASS")
PY

finished_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

echo "STEP: retain manifest-aligned Prometheus window"
"${ssh_obs[@]}" python3 - "$obs_ip" "$started_at" "$finished_at" \
  < "$root/scripts/reliability/capture-m10-prometheus.py" \
  > "$run_dir/prometheus.json"

python3 - \
  "$run_dir/run-manifest.json" \
  "$run_id" \
  "$actual_sha" \
  "$backend_release_sha" \
  "$frontend_release_sha" \
  "$ARP_M10_DATASET_MANIFEST_SHA" \
  "$overlay_sha" \
  "$K6_VERSION" \
  "$started_at" \
  "$finished_at" \
  "$fixture_sha" <<'PY'
import json
import sys

(
    output,
    run_id,
    source_sha,
    backend_release_sha,
    frontend_release_sha,
    dataset_manifest_sha,
    overlay_sha,
    k6_version,
    started_at,
    finished_at,
    fixture_sha,
) = sys.argv[1:]

manifest = {
    "schema_version": 1,
    "run_id": run_id,
    "source_sha": source_sha,
    "release_sha": backend_release_sha,
    "dataset": {
        "name": "M",
        "seed": 20260914,
        "manifest_version": f"sha256:{dataset_manifest_sha}",
        "overlay_version": f"sha256:{overlay_sha}",
    },
    "loadgen": {
        "region": "asia-northeast1",
        "zone": "asia-northeast1-a",
        "machine_type": "e2-standard-2",
        "k6_version": k6_version,
    },
    "workload": {
        "scenario": "m10-healthy-normal-control",
        "version": "1",
        "vus": 30,
        "duration": "5m",
        "mix_pct": {
            "list_detail": 40,
            "create_save": 15,
            "submit_resubmit": 10,
            "reviewer_queue_detail": 20,
            "review_action": 10,
            "attachment": 5,
        },
        "attachment_fixture": f"w1-attachment.txt sha256:{fixture_sha}",
    },
    "reliability": {
        "scenario": "healthy-control",
        "fault_injected": False,
        "purpose": "validate M10 evidence harness before R1-R3 fault injection",
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

summary_output=$(
  python3 - "$run_dir/k6-summary.json" <<'PY'
import json
import sys

metrics = json.load(open(sys.argv[1], encoding="utf-8")).get("metrics", {})
families = [
    ("list_detail", 40.0),
    ("create_save", 15.0),
    ("submit_resubmit", 10.0),
    ("reviewer_queue_detail", 20.0),
    ("review_action", 10.0),
    ("attachment", 5.0),
]

def metric(name):
    value = metrics.get(name)
    if not isinstance(value, dict):
        raise SystemExit(f"M10 summary missing {name}")
    return value

counts = {
    family: float(metric(f"m10_{family}_requests")["count"])
    for family, _ in families
}
total = sum(counts.values())
if total <= 0:
    raise SystemExit("M10 control recorded no business requests")

error_rate = float(metric("m10_non_file_errors")["value"])
p95 = float(metric("m10_non_file_duration")["p(95)"])
success_rate = 1.0 - error_rate
target_ok = success_rate >= 0.99 and p95 < 500.0

print(f"M10_CONTROL_BUSINESS_REQUESTS={int(total)}")
for family, target in families:
    observed = counts[family] / total * 100.0
    print(
        f"M10_CONTROL_MIX_{family.upper()}="
        f"count={int(counts[family])} observed_pct={observed:.2f} target_pct={target:.2f}"
    )
print(f"M10_CONTROL_NON_FILE_SUCCESS_RATE={success_rate:.6f}")
print(f"M10_CONTROL_NON_FILE_P95_MS={p95:.3f}")
print(f"M10_CONTROL_TARGET={'PASS' if target_ok else 'FAIL'}")
PY
)
printf '%s\n' "$summary_output"

echo "M10_CONTROL_RUN_ID=$run_id"
echo "M10_CONTROL_SOURCE_SHA=$actual_sha"
echo "M10_CONTROL_BACKEND_RELEASE_SHA=$backend_release_sha"
echo "M10_CONTROL_FRONTEND_RELEASE_SHA=$frontend_release_sha"
echo "M10_CONTROL_DATASET_MANIFEST_SHA256=$ARP_M10_DATASET_MANIFEST_SHA"
echo "M10_CONTROL_OVERLAY_SHA256=$overlay_sha"
echo "M10_CONTROL_ARTIFACT_DIR=$run_dir"

if ! grep -q '^M10_CONTROL_TARGET=PASS$' <<<"$summary_output"; then
  echo "ERROR: M10 healthy control did not meet the normal-load control target." >&2
  exit 1
fi

echo "PASS: M10 healthy control retained workload, business smoke, DB invariants, manifest, and telemetry evidence."
