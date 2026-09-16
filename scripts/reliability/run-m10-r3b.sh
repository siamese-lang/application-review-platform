#!/usr/bin/env bash
set -euo pipefail
umask 077

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root"

r3b_mode=${ARP_M10_R3B_MODE:-baseline}
case "$r3b_mode" in
  baseline)
    expected_garage_endpoint="http://10.40.0.41:3900"
    run_prefix="m10-r3b"
    application_endpoint_manifest="storage-01:3900"
    ;;
  retest)
    expected_garage_endpoint="http://127.0.0.1:3910"
    run_prefix="m10-r3b-retest"
    application_endpoint_manifest="127.0.0.1:3910"
    ;;
  *)
    echo "ERROR: ARP_M10_R3B_MODE must be baseline or retest." >&2
    exit 1
    ;;
esac

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
  : "${ARP_CONFIRM_M10_DATASET_RESET:?Set ARP_CONFIRM_M10_DATASET_RESET=yes for the guarded R3b reset}"
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
    raise SystemExit("M10 R3b could not capture dataset M manifest SHA-256")
print(match.group(1))
PY
  )

  rm -f "$dataset_log"
  trap - EXIT

  export ARP_M10_DATASET_READY=yes
  export ARP_M10_DATASET_MANIFEST_SHA="$dataset_manifest_sha"

  exec "$root/deploy/with-oslogin-ssh.py" \
    --ttl-seconds 1800 \
    -- bash "$root/scripts/reliability/run-m10-r3b.sh"
fi

[[ ${ARP_M10_DATASET_READY:-} == yes ]] || {
  echo "ERROR: M10 R3b must enter trusted SSH phase after dataset verification." >&2
  exit 1
}
[[ ${ARP_M10_DATASET_MANIFEST_SHA:-} =~ ^[0-9a-f]{64}$ ]] || {
  echo "ERROR: M10 R3b verified dataset manifest SHA-256 is missing." >&2
  exit 1
}

for command in python3 tar tofu ssh sha256sum date grep awk; do
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

read -r loadgen_ip app_ip edge_ip db_ip obs_ip storage1_ip storage2_ip storage3_ip < <(
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
    inventory["storage-01"]["private_ip"],
    inventory["storage-02"]["private_ip"],
    inventory["storage-03"]["private_ip"],
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
ssh_edge=("${ssh_common[@]}" "$ARP_OSLOGIN_USER@$edge_ip")
ssh_db=("${ssh_common[@]}" "$ARP_OSLOGIN_USER@$db_ip")
ssh_obs=("${ssh_common[@]}" "$ARP_OSLOGIN_USER@$obs_ip")
ssh_loadgen=("${ssh_common[@]}" "$ARP_OSLOGIN_USER@$loadgen_ip")
ssh_s1=("${ssh_common[@]}" "$ARP_OSLOGIN_USER@$storage1_ip")
ssh_s2=("${ssh_common[@]}" "$ARP_OSLOGIN_USER@$storage2_ip")
ssh_s3=("${ssh_common[@]}" "$ARP_OSLOGIN_USER@$storage3_ip")

overlay="$root/workload/sql/w2-interactive-overlay.sql"
overlay_sha=$(sha256sum "$overlay" | awk '{print $1}')
fixture="$root/workload/fixtures/w1-attachment.txt"
fixture_sha=$(sha256sum "$fixture" | awk '{print $1}')

echo "STEP: apply deterministic interactive overlay"
cat "$overlay" |
  "${ssh_db[@]}" sudo -u postgres psql -d arp -v ON_ERROR_STOP=1 >/dev/null

echo "STEP: verify post-R3a database and application health"
"${ssh_db[@]}" bash -s <<'REMOTE'
set -euo pipefail
[[ "$(systemctl show postgresql@16-main.service --property=NeedDaemonReload --value)" == no ]]
[[ "$(systemctl show postgresql@16-main.service --property=ActiveState --value)" == active ]]
[[ "$(systemctl show postgresql@16-main.service --property=SubState --value)" == running ]]
pg_isready -q -h 127.0.0.1 -p 5432
REMOTE

app_before=$("${ssh_app[@]}" systemctl show arp.service \
  --property=Id --property=ActiveState --property=SubState \
  --property=MainPID --property=NRestarts)
printf '%s\n' "$app_before"

read -r app_pid_before app_restarts_before < <(
  python3 - "$app_before" <<'PY'
import sys
values = {}
for raw in sys.argv[1].splitlines():
    if "=" in raw:
        key, value = raw.split("=", 1)
        values[key] = value
if values.get("Id") != "arp.service" or values.get("ActiveState") != "active" or values.get("SubState") != "running":
    raise SystemExit(f"application not healthy before R3b: {values!r}")
print(int(values["MainPID"]), int(values.get("NRestarts", "0")))
PY
)

garage_endpoint=$("${ssh_app[@]}" "sudo awk -F= '\$1==\"GARAGE_ENDPOINT\" {print \$2}' /etc/arp/arp.env")
[[ "$garage_endpoint" == "$expected_garage_endpoint" ]] || {
  echo "ERROR: application Garage endpoint mismatch: expected $expected_garage_endpoint, got $garage_endpoint" >&2
  exit 1
}

backend_state=$("${ssh_app[@]}" sudo cat /opt/arp/release-state/backend.json)
frontend_state=$("${ssh_edge[@]}" sudo cat /opt/arp/release-state/frontend.json)
read -r backend_release_sha frontend_release_sha < <(
  python3 - "$backend_state" "$frontend_state" <<'PY'
import json
import re
import sys

values = [json.loads(sys.argv[1]).get("current"), json.loads(sys.argv[2]).get("current")]
pattern = re.compile(r"^[0-9a-f]{40}$")
if any(not isinstance(value, str) or not pattern.fullmatch(value) for value in values):
    raise SystemExit(f"invalid component release state: {values!r}")
print(*values)
PY
)

run_id="${run_prefix}-$(date -u +%Y%m%dT%H%M%SZ)-${actual_sha:0:8}"
run_dir="$root/build/reliability/runs/$run_id"
mkdir -p "$run_dir"

echo "STEP: verify all Garage containers and capture node identities"
for entry in   "storage-01:$storage1_ip"   "storage-02:$storage2_ip"   "storage-03:$storage3_ip"
do
  host=${entry%%:*}
  ip=${entry#*:}
  ssh_node=("${ssh_common[@]}" "$ARP_OSLOGIN_USER@$ip")
  "${ssh_node[@]}" bash -s -- "$host" <<'REMOTE'
set -euo pipefail
host=$1
running=$(sudo docker inspect -f '{{.State.Running}}' garage)
policy=$(sudo docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' garage)
image=$(sudo docker inspect -f '{{.Config.Image}}' garage)
[[ "$running" == true ]]
[[ "$policy" == unless-stopped ]]
[[ "$image" == dxflrs/garage:v2.4.1 ]]
printf '%s_RUNNING=%s\n' "$host" "$running"
printf '%s_RESTART_POLICY=%s\n' "$host" "$policy"
printf '%s_IMAGE=%s\n' "$host" "$image"
sudo docker exec garage /garage -c /etc/garage.toml node id -q
REMOTE
done > "$run_dir/garage-preflight.txt"
cat "$run_dir/garage-preflight.txt"

node1_full=$("${ssh_s1[@]}" sudo docker exec garage /garage -c /etc/garage.toml node id -q)
node1_id=${node1_full%%@*}
[[ $node1_id =~ ^[0-9a-f]{64}$ ]] || {
  echo "ERROR: invalid storage-01 Garage node ID: $node1_full" >&2
  exit 1
}
node1_short=${node1_id:0:16}

"${ssh_s2[@]}" sudo docker exec garage /garage -c /etc/garage.toml status \
  > "$run_dir/garage-status-before.txt" 2>&1

python3 - "$run_dir/garage-status-before.txt" "$node1_short" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
short = sys.argv[2]
if "==== HEALTHY NODES ====" not in text:
    raise SystemExit("Garage pre-fault status has no HEALTHY NODES section")
healthy = text.split("==== HEALTHY NODES ====", 1)[1]
if "====" in healthy:
    healthy = healthy.split("====", 1)[0]
if short not in healthy:
    raise SystemExit("storage-01 is not healthy before R3b")
print("M10_R3B_PREFAULT_STORAGE01_HEALTHY=PASS")
PY

remote_dir=$("${ssh_loadgen[@]}" mktemp -d /tmp/arp-m10-r3b.XXXXXX)
[[ $remote_dir == /tmp/arp-m10-r3b.* ]] || {
  echo "ERROR: unexpected loadgen temporary directory: $remote_dir" >&2
  exit 1
}

k6_job=""
garage_fault_active=0
cleanup() {
  if [[ -n "$k6_job" ]]; then
    kill "$k6_job" >/dev/null 2>&1 || true
  fi
  "${ssh_loadgen[@]}" rm -rf -- "$remote_dir" >/dev/null 2>&1 || true
  if (( garage_fault_active == 1 )); then
    echo "EMERGENCY_RECOVERY: storage-01 Garage may still be stopped; starting it." >&2
    "${ssh_s1[@]}" sudo docker start garage >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

tar -C "$root/workload" -cf - k6/m10-r3b-garage-endpoint.js fixtures/w1-attachment.txt |
  "${ssh_loadgen[@]}" "tar -xf - -C '$remote_dir'"

remote_k6_version=$("${ssh_loadgen[@]}" k6 version)
[[ $remote_k6_version == *"k6 v$K6_VERSION"* ]] || {
  echo "ERROR: loadgen k6 version does not match repository pin: $remote_k6_version" >&2
  exit 1
}

base_url="https://$edge_public_ip"
started_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
k6_output="$run_dir/k6-output.txt"

remote_command="set -euo pipefail; IFS= read -r APPLICANT_PASSWORD; export APPLICANT_PASSWORD; cd '$remote_dir'; BASE_URL='$base_url' RUN_ID='$run_id' M10_DURATION='4m' APPLICANT_USERNAME='m6-applicant' ATTACHMENT_PATH='../fixtures/w1-attachment.txt' k6 run --summary-export summary.json k6/m10-r3b-garage-endpoint.js"

echo "STEP: start R3b attachment and non-attachment probes"
(
  printf '%s\n' "$SYNTHETIC_APPLICANT_PASSWORD" |
    "${ssh_loadgen[@]}" "$remote_command"
) >"$k6_output" 2>&1 &
k6_job=$!

echo "STEP: wait for healthy pre-fault R3b probes"
ready=0
for _ in $(seq 1 180); do
  if grep -q 'M10_R3B_ATTACHMENT_OK' "$k6_output" 2>/dev/null &&
     grep -q 'M10_R3B_NON_ATTACHMENT_OK' "$k6_output" 2>/dev/null; then
    ready=1
    break
  fi
  sleep 0.25
done
[[ $ready == 1 ]] || {
  echo "ERROR: R3b probes did not establish a healthy pre-fault baseline." >&2
  tail -n 120 "$k6_output" >&2 || true
  exit 1
}

sleep 20

fault_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
echo "STEP: stop storage-01 Garage container at $fault_at"
garage_fault_active=1
"${ssh_s1[@]}" sudo docker stop --time 10 garage >/dev/null

stopped_at=$(
  "${ssh_s1[@]}" bash -s <<'REMOTE'
set -euo pipefail
for _ in $(seq 1 200); do
  running=$(sudo docker inspect -f '{{.State.Running}}' garage)
  if [[ "$running" == false ]]; then
    date -u +%Y-%m-%dT%H:%M:%S.%3NZ
    exit 0
  fi
  sleep 0.1
done
echo "storage-01 Garage did not stop within 20 seconds" >&2
exit 1
REMOTE
)
echo "M10_R3B_STORAGE01_STOPPED_AT=$stopped_at"

echo "STEP: hold bounded endpoint node outage for 60 seconds"
sleep 20

"${ssh_s2[@]}" sudo docker exec garage /garage -c /etc/garage.toml status \
  > "$run_dir/garage-status-during-fault.txt" 2>&1

python3 - "$run_dir/garage-status-during-fault.txt" "$node1_short" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
short = sys.argv[2]
if "==== HEALTHY NODES ====" not in text:
    raise SystemExit("Garage fault-time status has no HEALTHY NODES section")
healthy = text.split("==== HEALTHY NODES ====", 1)[1]
if "====" in healthy:
    healthy = healthy.split("====", 1)[0]
if short in healthy:
    raise SystemExit("storage-01 still appears in HEALTHY NODES during R3b fault")
print("M10_R3B_STORAGE01_REMOVED_FROM_HEALTHY_SET=PASS")
PY

echo "STEP: retain database attachment lifecycle snapshot during R3b fault"
cat "$root/scripts/reliability/m10-db-invariants.sql" |
  "${ssh_db[@]}" sudo -u postgres psql -d arp -v ON_ERROR_STOP=1 \
  > "$run_dir/db-invariants-during-fault.txt"

during_invariant_summary=$(
  python3 - "$run_dir/db-invariants-during-fault.txt" <<'PY'
import sys
values = {}
for raw in open(sys.argv[1], encoding="utf-8"):
    raw = raw.strip()
    if "|" not in raw:
        continue
    key, value = raw.split("|", 1)
    try:
        values[key] = int(value)
    except ValueError:
        pass
for key in sorted(values):
    print(f"M10_R3B_DURING_{key.upper()}={values[key]}")
lifecycle = ["attachment_pending", "attachment_failed", "attachment_delete_pending"]
partial = any(values.get(key, 0) > 0 for key in lifecycle)
print(f"M10_R3B_DURING_PARTIAL_ATTACHMENT_STATE={'YES' if partial else 'NO'}")
PY
)
printf '%s\n' "$during_invariant_summary" | tee "$run_dir/during-invariant-summary.txt"

sleep 40

restore_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
echo "STEP: start storage-01 Garage container at $restore_at"
"${ssh_s1[@]}" sudo docker start garage >/dev/null

recovered_at=$(
  "${ssh_s2[@]}" bash -s -- "$node1_short" <<'REMOTE'
set -euo pipefail
short=$1
for _ in $(seq 1 600); do
  status=$(sudo docker exec garage /garage -c /etc/garage.toml status 2>&1 || true)
  healthy=$(awk '
    /==== HEALTHY NODES ====/ {inside=1; next}
    /^====/ && inside {exit}
    inside {print}
  ' <<<"$status")
  if grep -Fq "$short" <<<"$healthy"; then
    date -u +%Y-%m-%dT%H:%M:%S.%3NZ
    exit 0
  fi
  sleep 0.1
done
echo "storage-01 did not return to Garage healthy nodes within 60 seconds" >&2
exit 1
REMOTE
)
garage_fault_active=0
echo "M10_R3B_STORAGE01_HEALTHY_AT=$recovered_at"

"${ssh_s2[@]}" sudo docker exec garage /garage -c /etc/garage.toml status \
  > "$run_dir/garage-status-after.txt" 2>&1

set +e
wait "$k6_job"
k6_rc=$?
set -e
k6_job=""
if [[ $k6_rc -ne 0 ]]; then
  echo "ERROR: R3b k6 probe process exited with rc=$k6_rc" >&2
  tail -n 160 "$k6_output" >&2 || true
  exit 1
fi

"${ssh_loadgen[@]}" "cat '$remote_dir/summary.json'" > "$run_dir/k6-summary.json"
scenario_finished_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)

probe_summary=$(
  python3 - "$run_dir/k6-summary.json" "$r3b_mode" <<'PY'
import json
import sys

metrics = json.load(open(sys.argv[1], encoding="utf-8")).get("metrics", {})
mode = sys.argv[2]

def value(name, field):
    metric = metrics.get(name)
    if not isinstance(metric, dict) or field not in metric:
        raise SystemExit(f"missing k6 metric {name}.{field}")
    return float(metric[field])

attachment_attempts = value("m10_r3b_attachment_attempts", "count")
attachment_errors = value("m10_r3b_attachment_errors", "value")
existing_download_errors = value("m10_r3b_existing_download_errors", "value")
upload_errors = value("m10_r3b_attachment_upload_errors", "value")
uploaded_download_errors = value("m10_r3b_uploaded_download_errors", "value")
delete_errors = value("m10_r3b_attachment_delete_errors", "value")
non_attachment_attempts = value("m10_r3b_non_attachment_attempts", "count")
non_attachment_errors = value("m10_r3b_non_attachment_errors", "value")
support_errors = value("m10_r3b_support_errors", "value")

if attachment_attempts <= 0 or non_attachment_attempts <= 0:
    raise SystemExit("R3b probe recorded no attempts")

availability_gap = (
    attachment_errors > 0.0
    and existing_download_errors > 0.0
    and upload_errors > 0.0
)
unaffected_paths_healthy = (
    non_attachment_errors == 0.0
    and support_errors == 0.0
)
supported = availability_gap and unaffected_paths_healthy
attachment_continuity = (
    attachment_errors == 0.0
    and existing_download_errors == 0.0
    and upload_errors == 0.0
    and uploaded_download_errors == 0.0
    and delete_errors == 0.0
)
corrective_change_verified = attachment_continuity and unaffected_paths_healthy

print(f"M10_R3B_ATTACHMENT_ATTEMPTS={int(attachment_attempts)}")
print(f"M10_R3B_ATTACHMENT_ERROR_RATE={attachment_errors:.6f}")
print(f"M10_R3B_EXISTING_DOWNLOAD_ERROR_RATE={existing_download_errors:.6f}")
print(f"M10_R3B_ATTACHMENT_UPLOAD_ERROR_RATE={upload_errors:.6f}")
print(f"M10_R3B_UPLOADED_DOWNLOAD_ERROR_RATE={uploaded_download_errors:.6f}")
print(f"M10_R3B_ATTACHMENT_DELETE_ERROR_RATE={delete_errors:.6f}")
print(f"M10_R3B_NON_ATTACHMENT_ATTEMPTS={int(non_attachment_attempts)}")
print(f"M10_R3B_NON_ATTACHMENT_ERROR_RATE={non_attachment_errors:.6f}")
print(f"M10_R3B_SUPPORT_ERROR_RATE={support_errors:.6f}")
if mode == "baseline":
    print(f"M10_R3B_ENDPOINT_AVAILABILITY_GAP={'OBSERVED' if availability_gap else 'NOT_OBSERVED'}")
    print(f"M10_R3B_NON_ATTACHMENT_CONTINUITY={'PASS' if unaffected_paths_healthy else 'FAIL'}")
    print(f"M10_R3B_HYPOTHESIS={'SUPPORTED' if supported else 'NOT_SUPPORTED'}")
else:
    print(f"M10_R3B_RETEST_ATTACHMENT_CONTINUITY={'PASS' if attachment_continuity else 'FAIL'}")
    print(f"M10_R3B_RETEST_NON_ATTACHMENT_CONTINUITY={'PASS' if unaffected_paths_healthy else 'FAIL'}")
    print(f"M10_R3B_RETEST_CORRECTIVE_CHANGE={'VERIFIED' if corrective_change_verified else 'NOT_VERIFIED'}")
PY
)
printf '%s\n' "$probe_summary" | tee "$run_dir/probe-summary.txt"
if [[ "$r3b_mode" == retest ]] &&
   ! grep -q '^M10_R3B_RETEST_CORRECTIVE_CHANGE=VERIFIED
"${ssh_obs[@]}" python3 - "$obs_ip" "$started_at" "$scenario_finished_at" \
  < "$root/scripts/reliability/capture-m10-prometheus.py" \
  > "$run_dir/prometheus.json"

telemetry_summary=$(
  python3 - "$run_dir/prometheus.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))["queries"]

def values(name):
    out = []
    for series in data[name]["series"]:
        out.extend(value for _, value in series["values"])
    return out

pg = values("postgres_up")
app = values("application_probe")
if not pg or min(pg) != 1.0:
    raise SystemExit(f"PostgreSQL availability changed during R3b: {pg!r}")
if not app or min(app) != 1.0:
    raise SystemExit(f"application blackbox probe changed during R3b: {app!r}")

garage = {}
for series in data["garage_up_by_node"]["series"]:
    node = series["metric"].get("node")
    if not node:
        raise SystemExit(f"Garage up series missing node label: {series['metric']!r}")
    garage.setdefault(node, []).extend(value for _, value in series["values"])

for node in ["storage-01", "storage-02", "storage-03"]:
    if node not in garage or not garage[node]:
        raise SystemExit(f"missing Garage telemetry for {node}")

if min(garage["storage-02"]) != 1.0 or min(garage["storage-03"]) != 1.0:
    raise SystemExit(f"unrelated Garage peer node went down: {garage!r}")
if min(garage["storage-01"]) != 0.0 or max(garage["storage-01"]) != 1.0:
    raise SystemExit(f"storage-01 telemetry did not capture endpoint outage and recovery: {garage['storage-01']!r}")

print("M10_R3B_POSTGRES_UP_MIN=1")
print("M10_R3B_APPLICATION_PROBE_MIN=1")
for node in ["storage-01", "storage-02", "storage-03"]:
    print(f"M10_R3B_GARAGE_{node.upper().replace('-', '_')}_MIN={min(garage[node]):.0f}")
    print(f"M10_R3B_GARAGE_{node.upper().replace('-', '_')}_MAX={max(garage[node]):.0f}")
print("M10_R3B_TELEMETRY_NODE_ISOLATION=PASS")
PY
)
printf '%s\n' "$telemetry_summary" | tee "$run_dir/telemetry-summary.txt"

echo "STEP: verify application process remained stable"
app_after=$("${ssh_app[@]}" systemctl show arp.service \
  --property=Id --property=ActiveState --property=SubState \
  --property=MainPID --property=NRestarts)
python3 - "$app_after" "$app_pid_before" "$app_restarts_before" <<'PY'
import sys
values = {}
for raw in sys.argv[1].splitlines():
    if "=" in raw:
        key, value = raw.split("=", 1)
        values[key] = value
before_pid = int(sys.argv[2])
before_restarts = int(sys.argv[3])
if values.get("ActiveState") != "active" or values.get("SubState") != "running":
    raise SystemExit(f"application not healthy after R3b: {values!r}")
if int(values["MainPID"]) != before_pid:
    raise SystemExit(f"application PID changed during R3b: {before_pid} -> {values['MainPID']}")
if int(values.get("NRestarts", "0")) != before_restarts:
    raise SystemExit("application restart count changed during R3b")
print(f"M10_R3B_APP_PID_BEFORE={before_pid}")
print(f"M10_R3B_APP_PID_AFTER={values['MainPID']}")
print("M10_R3B_APPLICATION_STABLE=PASS")
PY

echo "STEP: post-R3b HTTPS business smoke"
BASE_URL="$base_url" \
REVIEWER_USERNAME=m6-reviewer \
REVIEWER_PASSWORD="$SYNTHETIC_REVIEWER_PASSWORD" \
ATTACHMENT_FIXTURE="$fixture" \
  bash "$root/deploy/cloud-smoke.sh" |
  tee "$run_dir/cloud-smoke.txt"

echo "STEP: post-R3b database business invariants"
cat "$root/scripts/reliability/m10-db-invariants.sql" |
  "${ssh_db[@]}" sudo -u postgres psql -d arp -v ON_ERROR_STOP=1 \
  > "$run_dir/db-invariants-after.txt"

post_invariant_summary=$(
  python3 - "$run_dir/db-invariants-after.txt" "$r3b_mode" <<'PY'
import sys

mode = sys.argv[2]

required_zero = {
    "non_draft_latest_history_mismatch",
    "in_review_without_reviewer",
    "audit_subject_count_violation",
    "available_attachment_metadata_incomplete",
}
lifecycle = {"attachment_pending", "attachment_failed", "attachment_delete_pending"}
values = {}
for raw in open(sys.argv[1], encoding="utf-8"):
    raw = raw.strip()
    if "|" not in raw:
        continue
    key, value = raw.split("|", 1)
    try:
        values[key] = int(value)
    except ValueError:
        pass

missing = required_zero - values.keys()
bad = {key: values[key] for key in required_zero if values.get(key) != 0}
if missing:
    raise SystemExit(f"missing invariant rows: {sorted(missing)}")
if bad:
    raise SystemExit(f"core business invariant violations: {bad}")

for key in sorted(values):
    print(f"M10_R3B_POST_{key.upper()}={values[key]}")

clean = all(values.get(key, 0) == 0 for key in lifecycle)
print("M10_R3B_DB_CORE_INVARIANTS=PASS")
print(f"M10_R3B_ATTACHMENT_LIFECYCLE_CLEAN={'PASS' if clean else 'FAIL'}")
print(f"M10_R3B_PARTIAL_STATE_RETAINED={'NO' if clean else 'YES'}")
if mode == "retest":
    print(f"M10_R3B_RETEST_ATTACHMENT_LIFECYCLE_CLEAN={'PASS' if clean else 'FAIL'}")
PY
)
printf '%s\n' "$post_invariant_summary" | tee "$run_dir/post-invariant-summary.txt"
if [[ "$r3b_mode" == retest ]] &&
   ! grep -q '^M10_R3B_RETEST_ATTACHMENT_LIFECYCLE_CLEAN=PASS

python3 - \
  "$run_dir/run-manifest.json" "$run_id" "$actual_sha" \
  "$backend_release_sha" "$frontend_release_sha" \
  "$ARP_M10_DATASET_MANIFEST_SHA" "$overlay_sha" "$K6_VERSION" \
  "$started_at" "$fault_at" "$stopped_at" "$restore_at" "$recovered_at" \
  "$scenario_finished_at" "$finished_at" "$fixture_sha" "$node1_id" \
  "$r3b_mode" "$application_endpoint_manifest" <<'PY'
import json
import sys

(
    output, run_id, source_sha, backend_release_sha, frontend_release_sha,
    dataset_manifest_sha, overlay_sha, k6_version,
    started_at, fault_at, stopped_at, restore_at, recovered_at,
    scenario_finished_at, finished_at, fixture_sha, node1_id,
    mode, application_endpoint,
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
        "name": "loadgen-01",
        "region": "asia-northeast1",
        "zone": "asia-northeast1-a",
        "private_ip": "10.50.0.10",
        "k6_version": k6_version,
    },
    "workload": {
        "scenario": "m10-r3b-garage-endpoint",
        "duration": "4m",
        "attachment_vus": 2,
        "non_attachment_vus": 2,
        "attachment_fixture": f"w1-attachment.txt sha256:{fixture_sha}",
    },
    "reliability": {
        "scenario": "R3b-garage-endpoint-node-loss",
        "fault_injected": True,
        "fault_target": "storage-01/garage",
        "fault_node_id": node1_id,
        "fault_mechanism": "docker stop --time 10 garage; docker start garage",
        "application_endpoint": application_endpoint,
        "mode": mode,
        "fault_at": fault_at,
        "container_stopped_at": stopped_at,
        "restore_at": restore_at,
        "cluster_healthy_at": recovered_at,
    },
    "runtime": {
        "component_releases": {
            "backend": backend_release_sha,
            "frontend": frontend_release_sha,
        },
        "garage": {
            "version": "v2.4.1",
            "replication_factor": 3,
            "faulted_node": "storage-01",
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
echo "$probe_summary"
echo "$during_invariant_summary"
echo "$telemetry_summary"
echo "$post_invariant_summary"
echo "M10_R3B_MODE=$r3b_mode"
echo "M10_R3B_RUN_ID=$run_id"
echo "M10_R3B_SOURCE_SHA=$actual_sha"
echo "M10_R3B_BACKEND_RELEASE_SHA=$backend_release_sha"
echo "M10_R3B_FRONTEND_RELEASE_SHA=$frontend_release_sha"
echo "M10_R3B_DATASET_MANIFEST_SHA256=$ARP_M10_DATASET_MANIFEST_SHA"
echo "M10_R3B_OVERLAY_SHA256=$overlay_sha"
echo "M10_R3B_FAULT_AT=$fault_at"
echo "M10_R3B_RESTORE_AT=$restore_at"
echo "M10_R3B_STORAGE01_HEALTHY_AT=$recovered_at"
echo "M10_R3B_ARTIFACT_DIR=$run_dir"
if [[ "$r3b_mode" == retest ]]; then
  echo "PASS: M10 R3b ADR-005 retest retained the storage-01 fault and verified proxy-backed attachment continuity, unaffected paths, telemetry, recovery, business smoke, and DB state."
else
  echo "PASS: M10 R3b experiment retained endpoint Garage fault, attachment/non-attachment observations, node telemetry, recovery, business smoke, and DB state."
fi
 <<<"$probe_summary"; then
  echo "ERROR: ADR-005 R3b retest observed an attachment or unaffected-path continuity failure." >&2
  exit 1
fi

echo "STEP: retain exact-window Prometheus evidence"
"${ssh_obs[@]}" python3 - "$obs_ip" "$started_at" "$scenario_finished_at" \
  < "$root/scripts/reliability/capture-m10-prometheus.py" \
  > "$run_dir/prometheus.json"

telemetry_summary=$(
  python3 - "$run_dir/prometheus.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))["queries"]

def values(name):
    out = []
    for series in data[name]["series"]:
        out.extend(value for _, value in series["values"])
    return out

pg = values("postgres_up")
app = values("application_probe")
if not pg or min(pg) != 1.0:
    raise SystemExit(f"PostgreSQL availability changed during R3b: {pg!r}")
if not app or min(app) != 1.0:
    raise SystemExit(f"application blackbox probe changed during R3b: {app!r}")

garage = {}
for series in data["garage_up_by_node"]["series"]:
    node = series["metric"].get("node")
    if not node:
        raise SystemExit(f"Garage up series missing node label: {series['metric']!r}")
    garage.setdefault(node, []).extend(value for _, value in series["values"])

for node in ["storage-01", "storage-02", "storage-03"]:
    if node not in garage or not garage[node]:
        raise SystemExit(f"missing Garage telemetry for {node}")

if min(garage["storage-02"]) != 1.0 or min(garage["storage-03"]) != 1.0:
    raise SystemExit(f"unrelated Garage peer node went down: {garage!r}")
if min(garage["storage-01"]) != 0.0 or max(garage["storage-01"]) != 1.0:
    raise SystemExit(f"storage-01 telemetry did not capture endpoint outage and recovery: {garage['storage-01']!r}")

print("M10_R3B_POSTGRES_UP_MIN=1")
print("M10_R3B_APPLICATION_PROBE_MIN=1")
for node in ["storage-01", "storage-02", "storage-03"]:
    print(f"M10_R3B_GARAGE_{node.upper().replace('-', '_')}_MIN={min(garage[node]):.0f}")
    print(f"M10_R3B_GARAGE_{node.upper().replace('-', '_')}_MAX={max(garage[node]):.0f}")
print("M10_R3B_TELEMETRY_NODE_ISOLATION=PASS")
PY
)
printf '%s\n' "$telemetry_summary" | tee "$run_dir/telemetry-summary.txt"

echo "STEP: verify application process remained stable"
app_after=$("${ssh_app[@]}" systemctl show arp.service \
  --property=Id --property=ActiveState --property=SubState \
  --property=MainPID --property=NRestarts)
python3 - "$app_after" "$app_pid_before" "$app_restarts_before" <<'PY'
import sys
values = {}
for raw in sys.argv[1].splitlines():
    if "=" in raw:
        key, value = raw.split("=", 1)
        values[key] = value
before_pid = int(sys.argv[2])
before_restarts = int(sys.argv[3])
if values.get("ActiveState") != "active" or values.get("SubState") != "running":
    raise SystemExit(f"application not healthy after R3b: {values!r}")
if int(values["MainPID"]) != before_pid:
    raise SystemExit(f"application PID changed during R3b: {before_pid} -> {values['MainPID']}")
if int(values.get("NRestarts", "0")) != before_restarts:
    raise SystemExit("application restart count changed during R3b")
print(f"M10_R3B_APP_PID_BEFORE={before_pid}")
print(f"M10_R3B_APP_PID_AFTER={values['MainPID']}")
print("M10_R3B_APPLICATION_STABLE=PASS")
PY

echo "STEP: post-R3b HTTPS business smoke"
BASE_URL="$base_url" \
REVIEWER_USERNAME=m6-reviewer \
REVIEWER_PASSWORD="$SYNTHETIC_REVIEWER_PASSWORD" \
ATTACHMENT_FIXTURE="$fixture" \
  bash "$root/deploy/cloud-smoke.sh" |
  tee "$run_dir/cloud-smoke.txt"

echo "STEP: post-R3b database business invariants"
cat "$root/scripts/reliability/m10-db-invariants.sql" |
  "${ssh_db[@]}" sudo -u postgres psql -d arp -v ON_ERROR_STOP=1 \
  > "$run_dir/db-invariants-after.txt"

post_invariant_summary=$(
  python3 - "$run_dir/db-invariants-after.txt" <<'PY'
import sys

required_zero = {
    "non_draft_latest_history_mismatch",
    "in_review_without_reviewer",
    "audit_subject_count_violation",
    "available_attachment_metadata_incomplete",
}
lifecycle = {"attachment_pending", "attachment_failed", "attachment_delete_pending"}
values = {}
for raw in open(sys.argv[1], encoding="utf-8"):
    raw = raw.strip()
    if "|" not in raw:
        continue
    key, value = raw.split("|", 1)
    try:
        values[key] = int(value)
    except ValueError:
        pass

missing = required_zero - values.keys()
bad = {key: values[key] for key in required_zero if values.get(key) != 0}
if missing:
    raise SystemExit(f"missing invariant rows: {sorted(missing)}")
if bad:
    raise SystemExit(f"core business invariant violations: {bad}")

for key in sorted(values):
    print(f"M10_R3B_POST_{key.upper()}={values[key]}")

clean = all(values.get(key, 0) == 0 for key in lifecycle)
print("M10_R3B_DB_CORE_INVARIANTS=PASS")
print(f"M10_R3B_ATTACHMENT_LIFECYCLE_CLEAN={'PASS' if clean else 'FAIL'}")
print(f"M10_R3B_PARTIAL_STATE_RETAINED={'NO' if clean else 'YES'}")
PY
)
printf '%s\n' "$post_invariant_summary" | tee "$run_dir/post-invariant-summary.txt"

finished_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)

python3 - \
  "$run_dir/run-manifest.json" "$run_id" "$actual_sha" \
  "$backend_release_sha" "$frontend_release_sha" \
  "$ARP_M10_DATASET_MANIFEST_SHA" "$overlay_sha" "$K6_VERSION" \
  "$started_at" "$fault_at" "$stopped_at" "$restore_at" "$recovered_at" \
  "$scenario_finished_at" "$finished_at" "$fixture_sha" "$node1_id" <<'PY'
import json
import sys

(
    output, run_id, source_sha, backend_release_sha, frontend_release_sha,
    dataset_manifest_sha, overlay_sha, k6_version,
    started_at, fault_at, stopped_at, restore_at, recovered_at,
    scenario_finished_at, finished_at, fixture_sha, node1_id,
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
        "name": "loadgen-01",
        "region": "asia-northeast1",
        "zone": "asia-northeast1-a",
        "private_ip": "10.50.0.10",
        "k6_version": k6_version,
    },
    "workload": {
        "scenario": "m10-r3b-garage-endpoint",
        "duration": "4m",
        "attachment_vus": 2,
        "non_attachment_vus": 2,
        "attachment_fixture": f"w1-attachment.txt sha256:{fixture_sha}",
    },
    "reliability": {
        "scenario": "R3b-garage-endpoint-node-loss",
        "fault_injected": True,
        "fault_target": "storage-01/garage",
        "fault_node_id": node1_id,
        "fault_mechanism": "docker stop --time 10 garage; docker start garage",
        "application_endpoint": "storage-01:3900",
        "fault_at": fault_at,
        "container_stopped_at": stopped_at,
        "restore_at": restore_at,
        "cluster_healthy_at": recovered_at,
    },
    "runtime": {
        "component_releases": {
            "backend": backend_release_sha,
            "frontend": frontend_release_sha,
        },
        "garage": {
            "version": "v2.4.1",
            "replication_factor": 3,
            "faulted_node": "storage-01",
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
echo "$probe_summary"
echo "$during_invariant_summary"
echo "$telemetry_summary"
echo "$post_invariant_summary"
echo "M10_R3B_RUN_ID=$run_id"
echo "M10_R3B_SOURCE_SHA=$actual_sha"
echo "M10_R3B_BACKEND_RELEASE_SHA=$backend_release_sha"
echo "M10_R3B_FRONTEND_RELEASE_SHA=$frontend_release_sha"
echo "M10_R3B_DATASET_MANIFEST_SHA256=$ARP_M10_DATASET_MANIFEST_SHA"
echo "M10_R3B_OVERLAY_SHA256=$overlay_sha"
echo "M10_R3B_FAULT_AT=$fault_at"
echo "M10_R3B_RESTORE_AT=$restore_at"
echo "M10_R3B_STORAGE01_HEALTHY_AT=$recovered_at"
echo "M10_R3B_ARTIFACT_DIR=$run_dir"
echo "PASS: M10 R3b experiment retained endpoint Garage fault, attachment/non-attachment observations, node telemetry, recovery, business smoke, and DB state."
 <<<"$post_invariant_summary"; then
  echo "ERROR: ADR-005 R3b retest left new attachment lifecycle residue." >&2
  exit 1
fi

finished_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)

python3 - \
  "$run_dir/run-manifest.json" "$run_id" "$actual_sha" \
  "$backend_release_sha" "$frontend_release_sha" \
  "$ARP_M10_DATASET_MANIFEST_SHA" "$overlay_sha" "$K6_VERSION" \
  "$started_at" "$fault_at" "$stopped_at" "$restore_at" "$recovered_at" \
  "$scenario_finished_at" "$finished_at" "$fixture_sha" "$node1_id" <<'PY'
import json
import sys

(
    output, run_id, source_sha, backend_release_sha, frontend_release_sha,
    dataset_manifest_sha, overlay_sha, k6_version,
    started_at, fault_at, stopped_at, restore_at, recovered_at,
    scenario_finished_at, finished_at, fixture_sha, node1_id,
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
        "name": "loadgen-01",
        "region": "asia-northeast1",
        "zone": "asia-northeast1-a",
        "private_ip": "10.50.0.10",
        "k6_version": k6_version,
    },
    "workload": {
        "scenario": "m10-r3b-garage-endpoint",
        "duration": "4m",
        "attachment_vus": 2,
        "non_attachment_vus": 2,
        "attachment_fixture": f"w1-attachment.txt sha256:{fixture_sha}",
    },
    "reliability": {
        "scenario": "R3b-garage-endpoint-node-loss",
        "fault_injected": True,
        "fault_target": "storage-01/garage",
        "fault_node_id": node1_id,
        "fault_mechanism": "docker stop --time 10 garage; docker start garage",
        "application_endpoint": "storage-01:3900",
        "fault_at": fault_at,
        "container_stopped_at": stopped_at,
        "restore_at": restore_at,
        "cluster_healthy_at": recovered_at,
    },
    "runtime": {
        "component_releases": {
            "backend": backend_release_sha,
            "frontend": frontend_release_sha,
        },
        "garage": {
            "version": "v2.4.1",
            "replication_factor": 3,
            "faulted_node": "storage-01",
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
echo "$probe_summary"
echo "$during_invariant_summary"
echo "$telemetry_summary"
echo "$post_invariant_summary"
echo "M10_R3B_RUN_ID=$run_id"
echo "M10_R3B_SOURCE_SHA=$actual_sha"
echo "M10_R3B_BACKEND_RELEASE_SHA=$backend_release_sha"
echo "M10_R3B_FRONTEND_RELEASE_SHA=$frontend_release_sha"
echo "M10_R3B_DATASET_MANIFEST_SHA256=$ARP_M10_DATASET_MANIFEST_SHA"
echo "M10_R3B_OVERLAY_SHA256=$overlay_sha"
echo "M10_R3B_FAULT_AT=$fault_at"
echo "M10_R3B_RESTORE_AT=$restore_at"
echo "M10_R3B_STORAGE01_HEALTHY_AT=$recovered_at"
echo "M10_R3B_ARTIFACT_DIR=$run_dir"
echo "PASS: M10 R3b experiment retained endpoint Garage fault, attachment/non-attachment observations, node telemetry, recovery, business smoke, and DB state."
 <<<"$probe_summary"; then
  echo "ERROR: ADR-005 R3b retest observed an attachment or unaffected-path continuity failure." >&2
  exit 1
fi

echo "STEP: retain exact-window Prometheus evidence"
"${ssh_obs[@]}" python3 - "$obs_ip" "$started_at" "$scenario_finished_at" \
  < "$root/scripts/reliability/capture-m10-prometheus.py" \
  > "$run_dir/prometheus.json"

telemetry_summary=$(
  python3 - "$run_dir/prometheus.json" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))["queries"]

def values(name):
    out = []
    for series in data[name]["series"]:
        out.extend(value for _, value in series["values"])
    return out

pg = values("postgres_up")
app = values("application_probe")
if not pg or min(pg) != 1.0:
    raise SystemExit(f"PostgreSQL availability changed during R3b: {pg!r}")
if not app or min(app) != 1.0:
    raise SystemExit(f"application blackbox probe changed during R3b: {app!r}")

garage = {}
for series in data["garage_up_by_node"]["series"]:
    node = series["metric"].get("node")
    if not node:
        raise SystemExit(f"Garage up series missing node label: {series['metric']!r}")
    garage.setdefault(node, []).extend(value for _, value in series["values"])

for node in ["storage-01", "storage-02", "storage-03"]:
    if node not in garage or not garage[node]:
        raise SystemExit(f"missing Garage telemetry for {node}")

if min(garage["storage-02"]) != 1.0 or min(garage["storage-03"]) != 1.0:
    raise SystemExit(f"unrelated Garage peer node went down: {garage!r}")
if min(garage["storage-01"]) != 0.0 or max(garage["storage-01"]) != 1.0:
    raise SystemExit(f"storage-01 telemetry did not capture endpoint outage and recovery: {garage['storage-01']!r}")

print("M10_R3B_POSTGRES_UP_MIN=1")
print("M10_R3B_APPLICATION_PROBE_MIN=1")
for node in ["storage-01", "storage-02", "storage-03"]:
    print(f"M10_R3B_GARAGE_{node.upper().replace('-', '_')}_MIN={min(garage[node]):.0f}")
    print(f"M10_R3B_GARAGE_{node.upper().replace('-', '_')}_MAX={max(garage[node]):.0f}")
print("M10_R3B_TELEMETRY_NODE_ISOLATION=PASS")
PY
)
printf '%s\n' "$telemetry_summary" | tee "$run_dir/telemetry-summary.txt"

echo "STEP: verify application process remained stable"
app_after=$("${ssh_app[@]}" systemctl show arp.service \
  --property=Id --property=ActiveState --property=SubState \
  --property=MainPID --property=NRestarts)
python3 - "$app_after" "$app_pid_before" "$app_restarts_before" <<'PY'
import sys
values = {}
for raw in sys.argv[1].splitlines():
    if "=" in raw:
        key, value = raw.split("=", 1)
        values[key] = value
before_pid = int(sys.argv[2])
before_restarts = int(sys.argv[3])
if values.get("ActiveState") != "active" or values.get("SubState") != "running":
    raise SystemExit(f"application not healthy after R3b: {values!r}")
if int(values["MainPID"]) != before_pid:
    raise SystemExit(f"application PID changed during R3b: {before_pid} -> {values['MainPID']}")
if int(values.get("NRestarts", "0")) != before_restarts:
    raise SystemExit("application restart count changed during R3b")
print(f"M10_R3B_APP_PID_BEFORE={before_pid}")
print(f"M10_R3B_APP_PID_AFTER={values['MainPID']}")
print("M10_R3B_APPLICATION_STABLE=PASS")
PY

echo "STEP: post-R3b HTTPS business smoke"
BASE_URL="$base_url" \
REVIEWER_USERNAME=m6-reviewer \
REVIEWER_PASSWORD="$SYNTHETIC_REVIEWER_PASSWORD" \
ATTACHMENT_FIXTURE="$fixture" \
  bash "$root/deploy/cloud-smoke.sh" |
  tee "$run_dir/cloud-smoke.txt"

echo "STEP: post-R3b database business invariants"
cat "$root/scripts/reliability/m10-db-invariants.sql" |
  "${ssh_db[@]}" sudo -u postgres psql -d arp -v ON_ERROR_STOP=1 \
  > "$run_dir/db-invariants-after.txt"

post_invariant_summary=$(
  python3 - "$run_dir/db-invariants-after.txt" <<'PY'
import sys

required_zero = {
    "non_draft_latest_history_mismatch",
    "in_review_without_reviewer",
    "audit_subject_count_violation",
    "available_attachment_metadata_incomplete",
}
lifecycle = {"attachment_pending", "attachment_failed", "attachment_delete_pending"}
values = {}
for raw in open(sys.argv[1], encoding="utf-8"):
    raw = raw.strip()
    if "|" not in raw:
        continue
    key, value = raw.split("|", 1)
    try:
        values[key] = int(value)
    except ValueError:
        pass

missing = required_zero - values.keys()
bad = {key: values[key] for key in required_zero if values.get(key) != 0}
if missing:
    raise SystemExit(f"missing invariant rows: {sorted(missing)}")
if bad:
    raise SystemExit(f"core business invariant violations: {bad}")

for key in sorted(values):
    print(f"M10_R3B_POST_{key.upper()}={values[key]}")

clean = all(values.get(key, 0) == 0 for key in lifecycle)
print("M10_R3B_DB_CORE_INVARIANTS=PASS")
print(f"M10_R3B_ATTACHMENT_LIFECYCLE_CLEAN={'PASS' if clean else 'FAIL'}")
print(f"M10_R3B_PARTIAL_STATE_RETAINED={'NO' if clean else 'YES'}")
PY
)
printf '%s\n' "$post_invariant_summary" | tee "$run_dir/post-invariant-summary.txt"

finished_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)

python3 - \
  "$run_dir/run-manifest.json" "$run_id" "$actual_sha" \
  "$backend_release_sha" "$frontend_release_sha" \
  "$ARP_M10_DATASET_MANIFEST_SHA" "$overlay_sha" "$K6_VERSION" \
  "$started_at" "$fault_at" "$stopped_at" "$restore_at" "$recovered_at" \
  "$scenario_finished_at" "$finished_at" "$fixture_sha" "$node1_id" <<'PY'
import json
import sys

(
    output, run_id, source_sha, backend_release_sha, frontend_release_sha,
    dataset_manifest_sha, overlay_sha, k6_version,
    started_at, fault_at, stopped_at, restore_at, recovered_at,
    scenario_finished_at, finished_at, fixture_sha, node1_id,
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
        "name": "loadgen-01",
        "region": "asia-northeast1",
        "zone": "asia-northeast1-a",
        "private_ip": "10.50.0.10",
        "k6_version": k6_version,
    },
    "workload": {
        "scenario": "m10-r3b-garage-endpoint",
        "duration": "4m",
        "attachment_vus": 2,
        "non_attachment_vus": 2,
        "attachment_fixture": f"w1-attachment.txt sha256:{fixture_sha}",
    },
    "reliability": {
        "scenario": "R3b-garage-endpoint-node-loss",
        "fault_injected": True,
        "fault_target": "storage-01/garage",
        "fault_node_id": node1_id,
        "fault_mechanism": "docker stop --time 10 garage; docker start garage",
        "application_endpoint": "storage-01:3900",
        "fault_at": fault_at,
        "container_stopped_at": stopped_at,
        "restore_at": restore_at,
        "cluster_healthy_at": recovered_at,
    },
    "runtime": {
        "component_releases": {
            "backend": backend_release_sha,
            "frontend": frontend_release_sha,
        },
        "garage": {
            "version": "v2.4.1",
            "replication_factor": 3,
            "faulted_node": "storage-01",
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
echo "$probe_summary"
echo "$during_invariant_summary"
echo "$telemetry_summary"
echo "$post_invariant_summary"
echo "M10_R3B_RUN_ID=$run_id"
echo "M10_R3B_SOURCE_SHA=$actual_sha"
echo "M10_R3B_BACKEND_RELEASE_SHA=$backend_release_sha"
echo "M10_R3B_FRONTEND_RELEASE_SHA=$frontend_release_sha"
echo "M10_R3B_DATASET_MANIFEST_SHA256=$ARP_M10_DATASET_MANIFEST_SHA"
echo "M10_R3B_OVERLAY_SHA256=$overlay_sha"
echo "M10_R3B_FAULT_AT=$fault_at"
echo "M10_R3B_RESTORE_AT=$restore_at"
echo "M10_R3B_STORAGE01_HEALTHY_AT=$recovered_at"
echo "M10_R3B_ARTIFACT_DIR=$run_dir"
echo "PASS: M10 R3b experiment retained endpoint Garage fault, attachment/non-attachment observations, node telemetry, recovery, business smoke, and DB state."
