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
  : "${ARP_CONFIRM_M10_DATASET_RESET:?Set ARP_CONFIRM_M10_DATASET_RESET=yes for the guarded R2 reset}"
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
    raise SystemExit("M10 R2 could not capture dataset M manifest SHA-256")
print(match.group(1))
PY
  )

  rm -f "$dataset_log"
  trap - EXIT

  export ARP_M10_DATASET_READY=yes
  export ARP_M10_DATASET_MANIFEST_SHA="$dataset_manifest_sha"

  exec "$root/deploy/with-oslogin-ssh.py" \
    --ttl-seconds 1800 \
    -- bash "$root/scripts/reliability/run-m10-r2.sh"
fi

[[ ${ARP_M10_DATASET_READY:-} == yes ]] || {
  echo "ERROR: M10 R2 must enter trusted SSH phase after dataset verification." >&2
  exit 1
}
[[ ${ARP_M10_DATASET_MANIFEST_SHA:-} =~ ^[0-9a-f]{64}$ ]] || {
  echo "ERROR: M10 R2 verified dataset manifest SHA-256 is missing." >&2
  exit 1
}

for command in python3 tar tofu ssh sha256sum date grep; do
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
ssh_edge=("${ssh_common[@]}" "$ARP_OSLOGIN_USER@$edge_private_ip")

overlay="$root/workload/sql/w2-interactive-overlay.sql"
overlay_sha=$(sha256sum "$overlay" | awk '{print $1}')
fixture="$root/workload/fixtures/w1-attachment.txt"
fixture_sha=$(sha256sum "$fixture" | awk '{print $1}')

echo "STEP: apply deterministic normal-load interactive overlay"
cat "$overlay" |
  "${ssh_db[@]}" sudo -u postgres psql -d arp -v ON_ERROR_STOP=1 >/dev/null

backend_state=$("${ssh_app[@]}" sudo cat /opt/arp/release-state/backend.json)
frontend_state=$("${ssh_edge[@]}" sudo cat /opt/arp/release-state/frontend.json)

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

app_before=$("${ssh_app[@]}" systemctl show arp.service \
  --property=Id --property=ActiveState --property=SubState \
  --property=MainPID --property=NRestarts)
printf '%s\n' "$app_before" >/tmp/m10-r2-app-before.$$

read -r app_pid_before app_restarts_before < <(
  python3 - /tmp/m10-r2-app-before.$$ <<'PY'
import sys
values = {}
for raw in open(sys.argv[1], encoding="utf-8"):
    raw = raw.strip()
    if "=" in raw:
        key, value = raw.split("=", 1)
        values[key] = value
if values.get("Id") != "arp.service" or values.get("ActiveState") != "active" or values.get("SubState") != "running":
    raise SystemExit(f"application not healthy before R2: {values!r}")
print(int(values["MainPID"]), int(values.get("NRestarts", "0")))
PY
)
rm -f /tmp/m10-r2-app-before.$$

db_before=$("${ssh_db[@]}" bash -s <<'REMOTE'
set -euo pipefail
unit=postgresql@16-main.service
[[ "$(systemctl show "$unit" --property=ActiveState --value)" == active ]]
[[ "$(systemctl show "$unit" --property=SubState --value)" == running ]]
pg_isready -q -h 127.0.0.1 -p 5432
pid=$(sudo head -n 1 /srv/postgresql/data/postmaster.pid)
printf 'unit=%s\n' "$unit"
printf 'main_pid=%s\n' "$pid"
printf 'alloy_active=%s\n' "$(systemctl show alloy.service --property=ActiveState --value)"
REMOTE
)
printf '%s\n' "$db_before"

db_pid_before=$(awk -F= '$1=="main_pid"{print $2}' <<<"$db_before")
[[ $db_pid_before =~ ^[0-9]+$ ]] || {
  echo "ERROR: could not capture pre-fault PostgreSQL postmaster PID." >&2
  exit 1
}
grep -q '^alloy_active=active$' <<<"$db_before" || {
  echo "ERROR: Alloy is not active before R2." >&2
  exit 1
}

base_url="https://$edge_public_ip"
run_id="m10-r2-$(date -u +%Y%m%dT%H%M%SZ)-${actual_sha:0:8}"
run_dir="$root/build/reliability/runs/$run_id"
mkdir -p "$run_dir"

remote_dir=$("${ssh_loadgen[@]}" mktemp -d /tmp/arp-m10-r2.XXXXXX)
[[ $remote_dir == /tmp/arp-m10-r2.* ]] || {
  echo "ERROR: unexpected loadgen temporary directory: $remote_dir" >&2
  exit 1
}

k6_job=""
db_fault_active=0
cleanup() {
  if [[ -n "$k6_job" ]]; then
    kill "$k6_job" >/dev/null 2>&1 || true
  fi
  "${ssh_loadgen[@]}" rm -rf -- "$remote_dir" >/dev/null 2>&1 || true
  if (( db_fault_active == 1 )); then
    echo "EMERGENCY_RECOVERY: PostgreSQL cluster unit may still be stopped; starting it." >&2
    "${ssh_db[@]}" sudo systemctl start postgresql@16-main.service >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

tar -C "$root/workload" -cf - k6/m10-r2-postgresql-outage.js fixtures/w1-attachment.txt |
  "${ssh_loadgen[@]}" "tar -xf - -C '$remote_dir'"

remote_k6_version=$("${ssh_loadgen[@]}" k6 version)
[[ $remote_k6_version == *"k6 v$K6_VERSION"* ]] || {
  echo "ERROR: loadgen k6 version does not match repository pin: $remote_k6_version" >&2
  exit 1
}

started_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
k6_output="$run_dir/k6-output.txt"
remote_command="set -euo pipefail; IFS= read -r APPLICANT_PASSWORD; IFS= read -r REVIEWER_PASSWORD; export APPLICANT_PASSWORD REVIEWER_PASSWORD; cd '$remote_dir'; BASE_URL='$base_url' RUN_ID='$run_id' M10_DURATION='5m' APPLICANT_USERNAME='m6-applicant' REVIEWER_USERNAME='m6-reviewer' ATTACHMENT_PATH='../fixtures/w1-attachment.txt' k6 run --summary-export summary.json k6/m10-r2-postgresql-outage.js"

echo "STEP: start R2 normal-load workload and boundary probes"
(
  {
    printf '%s\n' "$SYNTHETIC_APPLICANT_PASSWORD"
    printf '%s\n' "$SYNTHETIC_REVIEWER_PASSWORD"
  } |
    "${ssh_loadgen[@]}" "$remote_command"
) >"$k6_output" 2>&1 &
k6_job=$!

echo "STEP: wait for healthy pre-fault session/API/static-edge probes"
ready=0
for _ in $(seq 1 180); do
  if grep -q 'M10_R2_SESSION_READY' "$k6_output" 2>/dev/null &&
     grep -q 'probe=session|.*state=UP' "$k6_output" 2>/dev/null &&
     grep -q 'probe=public_api|.*state=UP' "$k6_output" 2>/dev/null &&
     grep -q 'probe=static_edge|.*state=UP' "$k6_output" 2>/dev/null; then
    ready=1
    break
  fi
  sleep 0.25
done
[[ $ready == 1 ]] || {
  echo "ERROR: R2 probes did not establish a healthy pre-fault baseline." >&2
  tail -n 120 "$k6_output" >&2 || true
  exit 1
}

sleep 30

fault_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
echo "STEP: stop PostgreSQL cluster unit at $fault_at"
db_fault_active=1
"${ssh_db[@]}" sudo systemctl stop postgresql@16-main.service

stopped_at=$(
  "${ssh_db[@]}" bash -s <<'REMOTE'
set -euo pipefail
for _ in $(seq 1 300); do
  state=$(systemctl show postgresql@16-main.service --property=ActiveState --value)
  if [[ "$state" != active ]] && ! pg_isready -q -h 127.0.0.1 -p 5432; then
    date -u +%Y-%m-%dT%H:%M:%S.%3NZ
    exit 0
  fi
  sleep 0.1
done
echo "PostgreSQL cluster did not become unavailable within 30 seconds" >&2
exit 1
REMOTE
)
echo "M10_R2_DB_STOPPED_AT=$stopped_at"

# Long enough for multiple 15 s telemetry samples, intentionally below the 5 m alert delay.
echo "STEP: hold bounded PostgreSQL outage for 60 seconds"
sleep 60

restore_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
echo "STEP: start PostgreSQL cluster unit at $restore_at"
"${ssh_db[@]}" sudo systemctl start postgresql@16-main.service

db_ready_observation=$(
  "${ssh_db[@]}" bash -s <<'REMOTE'
set -euo pipefail
for _ in $(seq 1 600); do
  state=$(systemctl show postgresql@16-main.service --property=ActiveState --value)
  if [[ "$state" == active ]] && pg_isready -q -h 127.0.0.1 -p 5432; then
    printf 'db_ready_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
    printf 'new_postmaster_pid=%s\n' "$(sudo head -n 1 /srv/postgresql/data/postmaster.pid)"
    exit 0
  fi
  sleep 0.1
done
echo "PostgreSQL cluster did not become ready within 60 seconds" >&2
exit 1
REMOTE
)
db_fault_active=0
printf '%s\n' "$db_ready_observation" | tee "$run_dir/db-ready.txt"

set +e
wait "$k6_job"
k6_rc=$?
set -e
k6_job=""
if [[ $k6_rc -ne 0 ]]; then
  echo "ERROR: R2 k6 workload exited with rc=$k6_rc" >&2
  tail -n 160 "$k6_output" >&2 || true
  exit 1
fi

"${ssh_loadgen[@]}" "cat '$remote_dir/summary.json'" > "$run_dir/k6-summary.json"
scenario_finished_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)

echo "STEP: retain R2 service and log evidence"
"${ssh_db[@]}" systemctl show postgresql@16-main.service \
  --property=Id --property=LoadState --property=ActiveState --property=SubState --property=MainPID \
  > "$run_dir/postgresql-after.txt"
"${ssh_db[@]}" systemctl show alloy.service \
  --property=Id --property=ActiveState --property=SubState --property=MainPID \
  > "$run_dir/alloy-after.txt"
"${ssh_app[@]}" systemctl show arp.service \
  --property=Id --property=ActiveState --property=SubState --property=MainPID --property=NRestarts \
  > "$run_dir/app-after.txt"

"${ssh_db[@]}" sudo journalctl -u postgresql@16-main.service \
  --since "$started_at" --until "$scenario_finished_at" --no-pager -o short-iso-precise \
  > "$run_dir/postgresql-journal.txt"
"${ssh_app[@]}" sudo journalctl -u arp.service \
  --since "$started_at" --until "$scenario_finished_at" --no-pager -o short-iso-precise \
  > "$run_dir/app-journal.txt"

transition_summary=$(
  python3 - "$k6_output" "$fault_at" "$restore_at" <<'PY'
from datetime import datetime
import re
import sys

path, fault_raw, restore_raw = sys.argv[1:]
fault = datetime.fromisoformat(fault_raw.replace("Z", "+00:00"))
restore = datetime.fromisoformat(restore_raw.replace("Z", "+00:00"))

pattern = re.compile(
    r"M10_R2_STATE\|probe=([^|]+)\|at=([^|]+)\|state=(UP|DOWN)\|status=([^|]+)\|"
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

def cycle(probe):
    seq = events[probe]
    initial = next((e for e in seq if e[1] == "UP" and e[0] < fault), None)
    down = next((e for e in seq if e[1] == "DOWN" and e[0] >= fault), None)
    up = next((e for e in seq if e[1] == "UP" and e[0] >= restore), None)
    if not initial:
        raise SystemExit(f"{probe}: no healthy state before fault")
    if not down:
        raise SystemExit(f"{probe}: no DOWN transition after DB fault")
    if not up:
        raise SystemExit(f"{probe}: no recovery after DB restore")
    return down, up

session_down, session_up = cycle("session")
api_down, api_up = cycle("public_api")
static_down = [e for e in events["static_edge"] if e[1] == "DOWN" and e[0] >= fault]
if static_down:
    raise SystemExit(f"static edge unexpectedly went DOWN: {static_down!r}")
if not any(e[1] == "UP" and e[0] < fault for e in events["static_edge"]):
    raise SystemExit("static edge had no healthy pre-fault state")

def ms(delta):
    return delta.total_seconds() * 1000.0

print(f"M10_R2_PUBLIC_API_DOWN_AT={api_down[0].isoformat().replace('+00:00','Z')}")
print(f"M10_R2_PUBLIC_API_UP_AT={api_up[0].isoformat().replace('+00:00','Z')}")
print(f"M10_R2_FAULT_TO_PUBLIC_API_DOWN_MS={ms(api_down[0]-fault):.3f}")
print(f"M10_R2_RESTORE_TO_PUBLIC_API_RECOVERY_MS={ms(api_up[0]-restore):.3f}")
print(f"M10_R2_SESSION_DOWN_AT={session_down[0].isoformat().replace('+00:00','Z')}")
print(f"M10_R2_SESSION_UP_AT={session_up[0].isoformat().replace('+00:00','Z')}")
print(f"M10_R2_RESTORE_TO_SESSION_RECOVERY_MS={ms(session_up[0]-restore):.3f}")
print("M10_R2_STATIC_EDGE_OUTAGE=NOT_OBSERVED")
PY
)
printf '%s\n' "$transition_summary" | tee "$run_dir/transition-summary.txt"

db_summary=$(
  python3 - "$run_dir/db-ready.txt" "$db_pid_before" "$restore_at" <<'PY'
from datetime import datetime
import sys

path, old_pid_raw, restore_raw = sys.argv[1:]
values = {}
for raw in open(path, encoding="utf-8"):
    raw = raw.strip()
    if "=" in raw:
        key, value = raw.split("=", 1)
        values[key] = value

ready = datetime.fromisoformat(values["db_ready_at"].replace("Z", "+00:00"))
restore = datetime.fromisoformat(restore_raw.replace("Z", "+00:00"))
old_pid = int(old_pid_raw)
new_pid = int(values["new_postmaster_pid"])
if new_pid <= 0 or new_pid == old_pid:
    raise SystemExit(f"PostgreSQL postmaster PID did not change: old={old_pid}, new={new_pid}")

print(f"M10_R2_OLD_POSTMASTER_PID={old_pid}")
print(f"M10_R2_NEW_POSTMASTER_PID={new_pid}")
print(f"M10_R2_DB_READY_AT={values['db_ready_at']}")
print(f"M10_R2_RESTORE_TO_DB_READY_MS={(ready-restore).total_seconds()*1000:.3f}")
print("M10_R2_DB_RESTORE=PASS")
PY
)
printf '%s\n' "$db_summary" | tee "$run_dir/db-summary.txt"

app_summary=$(
  python3 - "$run_dir/app-after.txt" "$app_pid_before" "$app_restarts_before" <<'PY'
import sys
values = {}
for raw in open(sys.argv[1], encoding="utf-8"):
    raw = raw.strip()
    if "=" in raw:
        key, value = raw.split("=", 1)
        values[key] = value

before_pid = int(sys.argv[2])
before_restarts = int(sys.argv[3])
after_pid = int(values["MainPID"])
after_restarts = int(values.get("NRestarts", "0"))

if values.get("ActiveState") != "active" or values.get("SubState") != "running":
    raise SystemExit(f"application not healthy after R2: {values!r}")
if after_pid != before_pid:
    raise SystemExit(f"application restarted during DB outage: {before_pid} -> {after_pid}")
if after_restarts != before_restarts:
    raise SystemExit(f"application NRestarts changed: {before_restarts} -> {after_restarts}")

print(f"M10_R2_APP_PID_BEFORE={before_pid}")
print(f"M10_R2_APP_PID_AFTER={after_pid}")
print(f"M10_R2_APP_NRESTARTS_BEFORE={before_restarts}")
print(f"M10_R2_APP_NRESTARTS_AFTER={after_restarts}")
print("M10_R2_APPLICATION_RECOVERED_WITHOUT_RESTART=PASS")
PY
)
printf '%s\n' "$app_summary" | tee "$run_dir/app-summary.txt"

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

login_attempts = value("m10_r2_session_login_attempts", "count")
session_error = value("m10_r2_session_probe_errors", "value")
api_error = value("m10_r2_public_api_probe_errors", "value")
static_error = value("m10_r2_static_edge_probe_errors", "value")
support_error = value("m10_r2_support_errors", "value")
non_file_error = value("m10_r2_non_file_errors", "value")

if login_attempts != 1:
    raise SystemExit(f"R2 probe re-authenticated unexpectedly: attempts={login_attempts}")
if session_error <= 0 or api_error <= 0:
    raise SystemExit("R2 probes did not observe the expected DB-dependent outage")
if static_error != 0:
    raise SystemExit(f"static edge probe observed errors: {static_error}")

print(f"M10_R2_SESSION_LOGIN_ATTEMPTS={int(login_attempts)}")
print(f"M10_R2_SESSION_PROBE_ERROR_RATE={session_error:.6f}")
print(f"M10_R2_PUBLIC_API_PROBE_ERROR_RATE={api_error:.6f}")
print(f"M10_R2_STATIC_EDGE_ERROR_RATE={static_error:.6f}")
print(f"M10_R2_SUPPORT_ERROR_RATE={support_error:.6f}")
print(f"M10_R2_NON_FILE_ERROR_RATE={non_file_error:.6f}")

families = [
    ("list_detail", 40.0),
    ("create_save", 15.0),
    ("submit_resubmit", 10.0),
    ("reviewer_queue_detail", 20.0),
    ("review_action", 10.0),
    ("attachment", 5.0),
]
attempts = {
    family: value(f"m10_r2_{family}_attempts", "count")
    for family, _ in families
}
total_attempts = sum(attempts.values())
if total_attempts <= 0:
    raise SystemExit("R2 workload recorded no business attempts")

print(f"M10_R2_BUSINESS_ATTEMPTS={int(total_attempts)}")
for family, target in families:
    count = value(f"m10_r2_{family}_requests", "count")
    error = value(f"m10_r2_{family}_errors", "value")
    observed = attempts[family] / total_attempts * 100.0
    print(
        f"M10_R2_FAMILY_{family.upper()}="
        f"attempts={int(attempts[family])} requests={int(count)} "
        f"offered_pct={observed:.2f} target_pct={target:.2f} error_rate={error:.6f}"
    )
print("M10_R2_EXPECTED_DB_DEPENDENT_OUTAGE_OBSERVED=PASS")
PY
)
printf '%s\n' "$k6_summary" | tee "$run_dir/k6-summary.txt"

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
probe = values("application_probe")
garage = values("garage_up_by_node")
pending = values("hikari_pending")

if not pg or min(pg) != 0.0 or max(pg) != 1.0:
    raise SystemExit(f"pg_up did not capture both outage and recovery: {pg!r}")
if not probe or min(probe) != 0.0 or max(probe) != 1.0:
    raise SystemExit(f"application probe did not capture both outage and recovery: {probe!r}")
if not garage or min(garage) != 1.0:
    raise SystemExit("Garage availability changed during R2")

print(f"M10_R2_PG_UP_MIN={min(pg):.0f}")
print(f"M10_R2_PG_UP_MAX={max(pg):.0f}")
print(f"M10_R2_APPLICATION_PROBE_MIN={min(probe):.0f}")
print(f"M10_R2_APPLICATION_PROBE_MAX={max(probe):.0f}")
print(f"M10_R2_HIKARI_PENDING_MAX={max(pending) if pending else 0.0:.3f}")
print(f"M10_R2_GARAGE_UP_MIN={min(garage):.0f}")
print("M10_R2_TELEMETRY_BLAST_RADIUS=PASS")
PY
)
printf '%s\n' "$telemetry_summary" | tee "$run_dir/telemetry-summary.txt"

echo "STEP: post-R2 HTTPS business smoke"
BASE_URL="$base_url" \
REVIEWER_USERNAME=m6-reviewer \
REVIEWER_PASSWORD="$SYNTHETIC_REVIEWER_PASSWORD" \
ATTACHMENT_FIXTURE="$fixture" \
  bash "$root/deploy/cloud-smoke.sh" |
  tee "$run_dir/cloud-smoke.txt"

echo "STEP: post-R2 database business invariants"
cat "$root/scripts/reliability/m10-db-invariants.sql" |
  "${ssh_db[@]}" sudo -u postgres psql -d arp -v ON_ERROR_STOP=1 \
  > "$run_dir/db-invariants.txt"

invariant_summary=$(
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
    print(f"M10_R2_INVARIANT_{key.upper()}={values[key]}")
print("M10_R2_DB_CORE_INVARIANTS=PASS")
PY
)
printf '%s\n' "$invariant_summary" | tee "$run_dir/invariant-summary.txt"

backend_state_after=$("${ssh_app[@]}" sudo cat /opt/arp/release-state/backend.json)
backend_release_after=$(python3 - "$backend_state_after" <<'PY'
import json, sys
print(json.loads(sys.argv[1])["current"])
PY
)
[[ "$backend_release_after" == "$backend_release_sha" ]] || {
  echo "ERROR: backend release identity changed during R2." >&2
  exit 1
}

finished_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)

python3 - \
  "$run_dir/run-manifest.json" "$run_id" "$actual_sha" \
  "$backend_release_sha" "$frontend_release_sha" \
  "$ARP_M10_DATASET_MANIFEST_SHA" "$overlay_sha" "$K6_VERSION" \
  "$started_at" "$fault_at" "$stopped_at" "$restore_at" "$scenario_finished_at" "$finished_at" \
  "$fixture_sha" "$db_pid_before" <<'PY'
import json
import sys

(
    output, run_id, source_sha, backend_release_sha, frontend_release_sha,
    dataset_manifest_sha, overlay_sha, k6_version,
    started_at, fault_at, stopped_at, restore_at, scenario_finished_at, finished_at,
    fixture_sha, db_pid_before,
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
        "scenario": "m10-r2-postgresql-outage",
        "version": "1",
        "business_vus": 30,
        "probe_vus": 3,
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
        "scenario": "R2-postgresql-outage",
        "fault_injected": True,
        "fault_target": "db-01/postgresql@16-main.service",
        "fault_mechanism": "systemctl stop/start postgresql@16-main.service",
        "pre_fault_postmaster_pid": int(db_pid_before),
        "fault_at": fault_at,
        "db_stopped_at": stopped_at,
        "restore_at": restore_at,
        "alert_delay": "5m; intentionally not exercised by this bounded 60s outage",
    },
    "runtime": {
        "project_id": "application-review-platform",
        "primary_region": "asia-northeast3",
        "component_releases": {
            "backend": backend_release_sha,
            "frontend": frontend_release_sha,
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
echo "$db_summary"
echo "$app_summary"
echo "$k6_summary"
echo "$telemetry_summary"
echo "$invariant_summary"
echo "M10_R2_RUN_ID=$run_id"
echo "M10_R2_SOURCE_SHA=$actual_sha"
echo "M10_R2_BACKEND_RELEASE_SHA=$backend_release_sha"
echo "M10_R2_FRONTEND_RELEASE_SHA=$frontend_release_sha"
echo "M10_R2_DATASET_MANIFEST_SHA256=$ARP_M10_DATASET_MANIFEST_SHA"
echo "M10_R2_OVERLAY_SHA256=$overlay_sha"
echo "M10_R2_FAULT_AT=$fault_at"
echo "M10_R2_RESTORE_AT=$restore_at"
echo "M10_R2_ARTIFACT_DIR=$run_dir"
echo "PASS: M10 R2 observed bounded PostgreSQL outage, expected DB-dependent blast radius, recovery without application restart/redeploy, telemetry transition, business smoke, and core DB invariants."
