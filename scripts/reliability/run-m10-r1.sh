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
  exec "$root/deploy/with-oslogin-ssh.py" \
    --ttl-seconds 1800 \
    -- bash "$root/scripts/reliability/run-m10-r1.sh"
fi

for command in python3 tar tofu ssh date; do
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

loadgen_json=$("${tofu_cmd[@]}" -chdir="$root/infra/opentofu" output -json loadgen)
inventory_json=$("${tofu_cmd[@]}" -chdir="$root/infra/opentofu" output -json inventory)
edge_public_ip=$("${tofu_cmd[@]}" -chdir="$root/infra/opentofu" output -raw edge_public_ip)

read -r loadgen_ip app_ip db_ip obs_ip < <(
  python3 - "$loadgen_json" "$inventory_json" <<'PY'
import ipaddress
import json
import sys

loadgen = json.loads(sys.argv[1])
inventory = json.loads(sys.argv[2])

expected_loadgen = {
    "name": "loadgen-01",
    "region": "asia-northeast1",
    "zone": "asia-northeast1-a",
    "private_ip": "10.50.0.10",
}
if loadgen != expected_loadgen:
    raise SystemExit(f"unexpected loadgen identity: {loadgen!r}")

values = [
    loadgen["private_ip"],
    inventory["app-01"]["private_ip"],
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

ssh_common=(
  ssh
  -i "$ARP_OSLOGIN_SSH_KEY"
  -o "UserKnownHostsFile=$ARP_OSLOGIN_KNOWN_HOSTS"
  -o StrictHostKeyChecking=yes
  -o IdentitiesOnly=yes
  -o ConnectTimeout=10
)
ssh_app=("${ssh_common[@]}" "$ARP_OSLOGIN_USER@$app_ip")
ssh_db=("${ssh_common[@]}" "$ARP_OSLOGIN_USER@$db_ip")
ssh_obs=("${ssh_common[@]}" "$ARP_OSLOGIN_USER@$obs_ip")
ssh_loadgen=("${ssh_common[@]}" "$ARP_OSLOGIN_USER@$loadgen_ip")

backend_state=$("${ssh_app[@]}" sudo cat /opt/arp/release-state/backend.json)
backend_release_sha=$(
  python3 - "$backend_state" <<'PY'
import json
import re
import sys

state = json.loads(sys.argv[1])
current = state.get("current")
if not isinstance(current, str) or not re.fullmatch(r"[0-9a-f]{40}", current):
    raise SystemExit(f"invalid backend release state: {state!r}")
print(current)
PY
)

base_url="https://$edge_public_ip"
run_id="m10-r1-$(date -u +%Y%m%dT%H%M%SZ)-${actual_sha:0:8}"
run_dir="$root/build/reliability/runs/$run_id"
mkdir -p "$run_dir"

service_before=$(
  "${ssh_app[@]}" sudo systemctl show arp.service \
    --property=Id \
    --property=LoadState \
    --property=ActiveState \
    --property=SubState \
    --property=MainPID \
    --property=Restart \
    --property=RestartUSec \
    --property=NRestarts
)
printf '%s\n' "$service_before" > "$run_dir/systemd-before.txt"

read -r old_pid restart_policy restarts_before active_before < <(
  python3 - "$run_dir/systemd-before.txt" <<'PY'
import sys

values = {}
for line in open(sys.argv[1], encoding="utf-8"):
    line = line.rstrip("\n")
    if "=" in line:
        key, value = line.split("=", 1)
        values[key] = value

required = {
    "Id": "arp.service",
    "LoadState": "loaded",
    "ActiveState": "active",
    "SubState": "running",
    "Restart": "on-failure",
}
for key, expected in required.items():
    if values.get(key) != expected:
        raise SystemExit(f"unexpected pre-fault systemd state: {key}={values.get(key)!r}")

pid = int(values.get("MainPID", "0"))
if pid <= 0:
    raise SystemExit("arp.service has no live MainPID")

print(pid, values["Restart"], int(values.get("NRestarts", "0")), values["ActiveState"])
PY
)

remote_dir=$("${ssh_loadgen[@]}" mktemp -d /tmp/arp-m10-r1.XXXXXX)
[[ $remote_dir == /tmp/arp-m10-r1.* ]] || {
  echo "ERROR: unexpected loadgen temporary directory: $remote_dir" >&2
  exit 1
}

k6_job=""
cleanup() {
  if [[ -n "$k6_job" ]]; then
    kill "$k6_job" >/dev/null 2>&1 || true
  fi
  "${ssh_loadgen[@]}" rm -rf -- "$remote_dir" >/dev/null 2>&1 || true
  if ! "${ssh_app[@]}" systemctl is-active --quiet arp.service >/dev/null 2>&1; then
    echo "EMERGENCY_RECOVERY: arp.service is not active; starting it." >&2
    "${ssh_app[@]}" sudo systemctl start arp.service >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

tar -C "$root/workload" -cf - k6/m10-r1-process-failure.js |
  "${ssh_loadgen[@]}" "tar -xf - -C '$remote_dir'"

remote_k6_version=$("${ssh_loadgen[@]}" k6 version)
[[ $remote_k6_version == *"k6 v$K6_VERSION"* ]] || {
  echo "ERROR: loadgen k6 version does not match repository pin: $remote_k6_version" >&2
  exit 1
}

started_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
k6_output="$run_dir/k6-output.txt"

remote_command="set -euo pipefail; IFS= read -r APPLICANT_PASSWORD; export APPLICANT_PASSWORD; cd '$remote_dir'; BASE_URL='$base_url' M10_DURATION='3m' APPLICANT_USERNAME='m6-applicant' k6 run --summary-export summary.json k6/m10-r1-process-failure.js"

echo "STEP: start R1 probe workload"
(
  printf '%s\n' "$SYNTHETIC_APPLICANT_PASSWORD" |
    "${ssh_loadgen[@]}" "$remote_command"
) >"$k6_output" 2>&1 &
k6_job=$!

echo "STEP: wait for pre-fault session/API/edge probes"
ready=0
for _ in $(seq 1 120); do
  if grep -q 'M10_R1_SESSION_READY' "$k6_output" 2>/dev/null &&
     grep -q 'probe=session|.*state=UP' "$k6_output" 2>/dev/null &&
     grep -q 'probe=public_api|.*state=UP' "$k6_output" 2>/dev/null &&
     grep -q 'probe=static_edge|.*state=UP' "$k6_output" 2>/dev/null; then
    ready=1
    break
  fi
  sleep 0.25
done

[[ $ready == 1 ]] || {
  echo "ERROR: R1 probes did not establish a healthy pre-fault baseline." >&2
  tail -n 80 "$k6_output" >&2 || true
  exit 1
}

sleep 30

fault_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
echo "STEP: inject bounded R1 main-process SIGKILL at $fault_at"
"${ssh_app[@]}" sudo systemctl kill --kill-who=main --signal=SIGKILL arp.service

restart_observation=$(
  "${ssh_app[@]}" bash -s -- "$old_pid" <<'REMOTE'
set -euo pipefail
old_pid=$1
for _ in $(seq 1 300); do
  state=$(systemctl show arp.service --property=ActiveState --value)
  pid=$(systemctl show arp.service --property=MainPID --value)
  if [[ "$state" == active && "$pid" =~ ^[0-9]+$ && "$pid" -gt 0 && "$pid" != "$old_pid" ]]; then
    printf 'restart_observed_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
    printf 'new_pid=%s\n' "$pid"
    exit 0
  fi
  sleep 0.1
done
echo "automatic restart was not observed within 30 seconds" >&2
exit 1
REMOTE
)
printf '%s\n' "$restart_observation" | tee "$run_dir/restart-observation.txt"

set +e
wait "$k6_job"
k6_rc=$?
set -e
k6_job=""

if [[ $k6_rc -ne 0 ]]; then
  echo "ERROR: R1 k6 probe process exited with rc=$k6_rc" >&2
  tail -n 120 "$k6_output" >&2 || true
  exit 1
fi

"${ssh_loadgen[@]}" "cat '$remote_dir/summary.json'" > "$run_dir/k6-summary.json"
scenario_finished_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)

echo "STEP: retain post-fault systemd and journal evidence"
"${ssh_app[@]}" sudo systemctl show arp.service \
  --property=Id \
  --property=LoadState \
  --property=ActiveState \
  --property=SubState \
  --property=MainPID \
  --property=ExecMainCode \
  --property=ExecMainStatus \
  --property=Restart \
  --property=RestartUSec \
  --property=NRestarts \
  > "$run_dir/systemd-after.txt"

"${ssh_app[@]}" sudo journalctl -u arp.service \
  --since "$started_at" \
  --until "$scenario_finished_at" \
  --no-pager -o short-iso-precise \
  > "$run_dir/app-journal.txt"

transition_summary=$(
  python3 - "$k6_output" "$fault_at" <<'PY'
from __future__ import annotations

from datetime import datetime
import re
import sys

path, fault_raw = sys.argv[1:]
fault = datetime.fromisoformat(fault_raw.replace("Z", "+00:00"))

pattern = re.compile(
    r"M10_R1_STATE\|probe=([^|]+)\|at=([^|]+)\|state=(UP|DOWN)\|status=([^|]+)\|"
)
events = {"session": [], "public_api": [], "static_edge": []}

for line in open(path, encoding="utf-8", errors="replace"):
    match = pattern.search(line)
    if not match:
        continue
    probe, at_raw, state, status = match.groups()
    if probe not in events:
        continue
    at = datetime.fromisoformat(at_raw.replace("Z", "+00:00"))
    events[probe].append((at, state, status))

def require_cycle(probe: str):
    seq = events[probe]
    initial_up = next((event for event in seq if event[1] == "UP" and event[0] < fault), None)
    down = next((event for event in seq if event[1] == "DOWN" and event[0] >= fault), None)
    if initial_up is None:
        raise SystemExit(f"{probe}: no healthy state before fault")
    if down is None:
        raise SystemExit(f"{probe}: no observed DOWN transition after fault")
    recovered = next((event for event in seq if event[1] == "UP" and event[0] > down[0]), None)
    if recovered is None:
        raise SystemExit(f"{probe}: no observed UP transition after DOWN")
    return down, recovered

session_down, session_up = require_cycle("session")
api_down, api_up = require_cycle("public_api")

static_down = [
    event for event in events["static_edge"]
    if event[1] == "DOWN" and event[0] >= fault
]
if static_down:
    raise SystemExit(f"static edge unexpectedly went DOWN: {static_down!r}")

static_up_before = next(
    (event for event in events["static_edge"] if event[1] == "UP" and event[0] < fault),
    None,
)
if static_up_before is None:
    raise SystemExit("static edge had no healthy state before fault")

def ms(delta):
    return delta.total_seconds() * 1000.0

print(f"M10_R1_PUBLIC_API_DOWN_AT={api_down[0].isoformat().replace('+00:00', 'Z')}")
print(f"M10_R1_PUBLIC_API_UP_AT={api_up[0].isoformat().replace('+00:00', 'Z')}")
print(f"M10_R1_PUBLIC_API_OUTAGE_MS={ms(api_up[0] - api_down[0]):.3f}")
print(f"M10_R1_FAULT_TO_PUBLIC_API_RECOVERY_MS={ms(api_up[0] - fault):.3f}")
print(f"M10_R1_SESSION_DOWN_AT={session_down[0].isoformat().replace('+00:00', 'Z')}")
print(f"M10_R1_SESSION_UP_AT={session_up[0].isoformat().replace('+00:00', 'Z')}")
print(f"M10_R1_SESSION_OUTAGE_MS={ms(session_up[0] - session_down[0]):.3f}")
print("M10_R1_STATIC_EDGE_OUTAGE=NOT_OBSERVED")
PY
)
printf '%s\n' "$transition_summary" | tee "$run_dir/transition-summary.txt"

systemd_summary=$(
  python3 - "$run_dir/systemd-before.txt" "$run_dir/systemd-after.txt" <<'PY'
import sys

def load(path):
    result = {}
    for raw in open(path, encoding="utf-8"):
        raw = raw.rstrip("\n")
        if "=" in raw:
            key, value = raw.split("=", 1)
            result[key] = value
    return result

before = load(sys.argv[1])
after = load(sys.argv[2])

old_pid = int(before["MainPID"])
new_pid = int(after["MainPID"])
before_restarts = int(before.get("NRestarts", "0"))
after_restarts = int(after.get("NRestarts", "0"))

if after.get("ActiveState") != "active" or after.get("SubState") != "running":
    raise SystemExit(f"arp.service not recovered: {after!r}")
if new_pid <= 0 or new_pid == old_pid:
    raise SystemExit(f"MainPID did not change: old={old_pid}, new={new_pid}")
if after_restarts <= before_restarts:
    raise SystemExit(
        f"NRestarts did not increase: before={before_restarts}, after={after_restarts}"
    )

print(f"M10_R1_OLD_PID={old_pid}")
print(f"M10_R1_NEW_PID={new_pid}")
print(f"M10_R1_NRESTARTS_BEFORE={before_restarts}")
print(f"M10_R1_NRESTARTS_AFTER={after_restarts}")
print("M10_R1_SYSTEMD_AUTO_RESTART=PASS")
PY
)
printf '%s\n' "$systemd_summary" | tee "$run_dir/systemd-summary.txt"

k6_summary=$(
  python3 - "$run_dir/k6-summary.json" <<'PY'
import json
import sys

metrics = json.load(open(sys.argv[1], encoding="utf-8")).get("metrics", {})

def value(name, field):
    metric = metrics.get(name)
    if not isinstance(metric, dict) or field not in metric:
        raise SystemExit(f"missing k6 metric {name}.{field}")
    return float(metric[field])

login_attempts = value("m10_r1_session_login_attempts", "count")
session_error = value("m10_r1_session_errors", "value")
api_error = value("m10_r1_public_api_errors", "value")
static_error = value("m10_r1_static_edge_errors", "value")

if login_attempts != 1:
    raise SystemExit(f"session probe re-authenticated unexpectedly: attempts={login_attempts}")
if session_error <= 0:
    raise SystemExit("session probe did not observe the application outage")
if api_error <= 0:
    raise SystemExit("public API probe did not observe the application outage")
if static_error != 0:
    raise SystemExit(f"static edge probe observed errors: rate={static_error}")

print(f"M10_R1_SESSION_LOGIN_ATTEMPTS={int(login_attempts)}")
print(f"M10_R1_SESSION_ERROR_RATE={session_error:.6f}")
print(f"M10_R1_PUBLIC_API_ERROR_RATE={api_error:.6f}")
print(f"M10_R1_STATIC_EDGE_ERROR_RATE={static_error:.6f}")
print("M10_R1_PERSISTED_SESSION_RECOVERY=PASS")
PY
)
printf '%s\n' "$k6_summary" | tee "$run_dir/k6-summary.txt"

echo "STEP: retain exact-window Prometheus evidence"
"${ssh_obs[@]}" python3 - "$obs_ip" "$started_at" "$scenario_finished_at" \
  < "$root/scripts/reliability/capture-m10-prometheus.py" \
  > "$run_dir/prometheus.json"

python3 - "$run_dir/prometheus.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))["queries"]

def values(name):
    result = []
    for series in data[name]["series"]:
        result.extend(value for _, value in series["values"])
    return result

pg = values("postgres_up")
garage = values("garage_up_by_node")

if not pg or min(pg) != 1.0:
    raise SystemExit(f"PostgreSQL availability changed during R1: samples={pg!r}")
if not garage or min(garage) != 1.0:
    raise SystemExit("Garage availability changed during R1")

print(f"M10_R1_POSTGRES_UP_SAMPLES={len(pg)}")
print(f"M10_R1_GARAGE_UP_SAMPLES={len(garage)}")
print("M10_R1_UNRELATED_DATA_SERVICES_HEALTHY=PASS")
PY

echo "STEP: post-R1 HTTPS business smoke"
fixture="$root/workload/fixtures/w1-attachment.txt"
BASE_URL="$base_url" \
REVIEWER_USERNAME=m6-reviewer \
REVIEWER_PASSWORD="$SYNTHETIC_REVIEWER_PASSWORD" \
ATTACHMENT_FIXTURE="$fixture" \
  bash "$root/deploy/cloud-smoke.sh" |
  tee "$run_dir/cloud-smoke.txt"

echo "STEP: post-R1 database business invariants"
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
    print(f"M10_R1_INVARIANT_{key.upper()}={values[key]}")
print("M10_R1_DB_INVARIANTS=PASS")
PY

backend_state_after=$("${ssh_app[@]}" sudo cat /opt/arp/release-state/backend.json)
backend_release_after=$(
  python3 - "$backend_state_after" <<'PY'
import json
import sys
print(json.loads(sys.argv[1])["current"])
PY
)
[[ "$backend_release_after" == "$backend_release_sha" ]] || {
  echo "ERROR: backend release identity changed during R1." >&2
  exit 1
}

finished_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)

python3 - \
  "$run_dir/run-manifest.json" \
  "$run_id" \
  "$actual_sha" \
  "$backend_release_sha" \
  "$started_at" \
  "$fault_at" \
  "$scenario_finished_at" \
  "$finished_at" \
  "$old_pid" \
  "$restarts_before" <<'PY'
import json
import sys

(
    output,
    run_id,
    source_sha,
    backend_release_sha,
    started_at,
    fault_at,
    scenario_finished_at,
    finished_at,
    old_pid,
    restarts_before,
) = sys.argv[1:]

manifest = {
    "schema_version": 1,
    "run_id": run_id,
    "source_sha": source_sha,
    "release_sha": backend_release_sha,
    "dataset": {
        "name": "M",
        "seed": 20260914,
        "manifest_version": "sha256:9e174ead7c9ae7b77d5adc18c93e336b4cac5e30b5962bf47c31de4f42bea696",
        "overlay_version": "sha256:f93dfb6a030fa552de3dd4c7b9c022368079680bf2b16b13c05883e8b678aae1",
    },
    "loadgen": {
        "name": "loadgen-01",
        "region": "asia-northeast1",
        "zone": "asia-northeast1-a",
        "private_ip": "10.50.0.10",
    },
    "workload": {
        "scenario": "m10-r1-process-failure-probes",
        "version": "1",
        "duration": "3m",
        "probes": ["persisted-session", "public-api", "static-edge"],
    },
    "reliability": {
        "scenario": "R1-application-process-failure",
        "fault_injected": True,
        "fault_target": "app-01/arp.service/MainPID",
        "fault_mechanism": "systemctl kill --kill-who=main --signal=SIGKILL arp.service",
        "systemd_restart_contract": "Restart=on-failure",
        "pre_fault_main_pid": int(old_pid),
        "pre_fault_nrestarts": int(restarts_before),
        "fault_at": fault_at,
    },
    "runtime": {
        "project_id": "application-review-platform",
        "primary_region": "asia-northeast3",
        "component_releases": {
            "backend": backend_release_sha,
        },
    },
    "started_at": started_at,
    "scenario_finished_at": scenario_finished_at,
    "finished_at": finished_at,
}

with open(output, "w", encoding="utf-8") as handle:
    json.dump(manifest, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY

echo
echo "$transition_summary"
echo "$systemd_summary"
echo "$k6_summary"
echo "M10_R1_RUN_ID=$run_id"
echo "M10_R1_SOURCE_SHA=$actual_sha"
echo "M10_R1_BACKEND_RELEASE_SHA=$backend_release_sha"
echo "M10_R1_FAULT_AT=$fault_at"
echo "M10_R1_ARTIFACT_DIR=$run_dir"
echo "PASS: M10 R1 observed process failure, automatic restart, session/API recovery, unaffected static edge, healthy data services, business smoke, and DB invariants."
