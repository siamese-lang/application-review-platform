#!/usr/bin/env bash
set -euo pipefail
umask 077

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
checkpoint_id=${1:-"m11-checkpoint-$(date -u +%Y%m%dT%H%M%SZ)"}

if [[ ! $checkpoint_id =~ ^[A-Za-z0-9._-]+$ || ${#checkpoint_id} -gt 80 ]]; then
  echo "invalid checkpoint id: $checkpoint_id" >&2
  exit 2
fi

if [[ -z ${ARP_OSLOGIN_USER:-} || -z ${ARP_OSLOGIN_SSH_KEY:-} || -z ${ARP_OSLOGIN_KNOWN_HOSTS:-} ]]; then
  exec "$root/deploy/with-oslogin-ssh.py" --ttl-seconds 1800 -- "$0" "$checkpoint_id"
fi

for command in ansible-playbook curl python3 ssh tofu; do
  command -v "$command" >/dev/null || {
    echo "missing checkpoint prerequisite: $command" >&2
    exit 1
  }
done

tofu_cmd=(tofu)
if [[ $EUID -ne 0 ]]; then
  tofu_cmd=(sudo -n tofu)
fi

inventory_json=$(mktemp)
inventory_yml=$(mktemp)
secret_vars=$(mktemp)
decrypted_secrets=
gate_enabled=false
app_stopped=false

ssh_base=(
  ssh
  -i "$ARP_OSLOGIN_SSH_KEY"
  -o "UserKnownHostsFile=$ARP_OSLOGIN_KNOWN_HOSTS"
  -o StrictHostKeyChecking=yes
  -o IdentitiesOnly=yes
)

node_ip() {
  python3 - "$inventory_json" "$1" <<'PY'
import json
import sys

inventory = json.load(open(sys.argv[1], encoding="utf-8"))
name = sys.argv[2]
try:
    print(inventory[name]["private_ip"])
except KeyError as exc:
    raise SystemExit(f"missing inventory node: {name}") from exc
PY
}

ssh_node() {
  local ip=$1
  shift
  "${ssh_base[@]}" "$ARP_OSLOGIN_USER@$ip" "$@"
}

run_gate() {
  local mode=$1
  ssh_node "$edge_ip" sudo bash -s -- "$mode" \
    < "$root/scripts/backup/run-m11-mutation-gate.sh"
}

wait_app_health() {
  ssh_node "$app_ip" sudo bash -s <<'REMOTE'
set -euo pipefail
for _ in $(seq 1 90); do
  if curl -fsS http://127.0.0.1:9091/actuator/health | grep -Fq '"status":"UP"'; then
    exit 0
  fi
  sleep 1
done
journalctl -u arp -n 120 --no-pager >&2 || true
echo "application did not become healthy after checkpoint" >&2
exit 1
REMOTE
}

attachment_counts() {
  ssh_node "$db_ip" sudo bash -s <<'REMOTE'
set -euo pipefail
sudo -u postgres psql --no-psqlrc -At -F '|' --dbname=arp <<'SQL'
SELECT
  count(*) FILTER (WHERE status='PENDING'),
  count(*) FILTER (WHERE status='DELETE_PENDING'),
  count(*) FILTER (WHERE status='AVAILABLE'),
  count(*) FILTER (WHERE status='FAILED'),
  count(*)
FROM attachments;
SQL
REMOTE
}

cleanup() {
  local rc=$?
  trap - EXIT
  set +e

  app_recovered=true
  if [[ $app_stopped == true ]]; then
    echo "M11_CHECKPOINT_CLEANUP=starting_application" >&2
    ssh_node "$app_ip" sudo systemctl start arp
    if wait_app_health; then
      app_stopped=false
    else
      app_recovered=false
      echo "M11_CHECKPOINT_CLEANUP=application_recovery_failed" >&2
    fi
  fi

  if [[ $gate_enabled == true ]]; then
    if [[ $app_recovered == true ]]; then
      echo "M11_CHECKPOINT_CLEANUP=disabling_mutation_gate" >&2
      if run_gate disable; then
        gate_enabled=false
      else
        echo "M11_CHECKPOINT_CLEANUP=mutation_gate_disable_failed" >&2
      fi
    else
      echo "M11_CHECKPOINT_CLEANUP=mutation_gate_left_enabled_for_safety" >&2
    fi
  fi

  rm -f "$inventory_json" "$inventory_yml" "$secret_vars"
  [[ -z $decrypted_secrets ]] || rm -f "$decrypted_secrets"

  if (( rc != 0 )); then
    echo "M11_CHECKPOINT=FAILED checkpoint_id=$checkpoint_id" >&2
  fi
  exit "$rc"
}
trap cleanup EXIT

"${tofu_cmd[@]}" -chdir="$root/infra/opentofu" output -json inventory >"$inventory_json"
python3 "$root/deploy/generate-inventory.py" <"$inventory_json" >"$inventory_yml"

edge_ip=$(node_ip edge-01)
app_ip=$(node_ip app-01)
db_ip=$(node_ip db-01)
storage_ip=$(node_ip storage-01)
backup_ip=$(node_ip backup-01)
garage_endpoint="http://$storage_ip:3900"
garage_bucket=application-review

initial_gate=$(run_gate status)
printf '%s\n' "$initial_gate"
grep -Fq 'M11_MUTATION_GATE=DISABLED' <<<"$initial_gate" || {
  echo "refusing checkpoint because mutation gate is not initially disabled" >&2
  exit 1
}

initial_app_state=$(ssh_node "$app_ip" systemctl is-active arp || true)
[[ $initial_app_state == active ]] || {
  echo "refusing checkpoint because arp.service is not initially active: $initial_app_state" >&2
  exit 1
}

if [[ -n ${GARAGE_ACCESS_KEY:-} && -n ${GARAGE_SECRET_KEY:-} ]]; then
  GARAGE_ACCESS_KEY="$GARAGE_ACCESS_KEY" GARAGE_SECRET_KEY="$GARAGE_SECRET_KEY" \
    python3 - "$secret_vars" <<'PY'
import json
import os
import sys

with open(sys.argv[1], "w", encoding="utf-8") as handle:
    json.dump(
        {
            "garage_app_access_key": os.environ["GARAGE_ACCESS_KEY"],
            "garage_app_secret_key": os.environ["GARAGE_SECRET_KEY"],
        },
        handle,
    )
PY
else
  : "${SOPS_AGE_KEY_FILE:?Set SOPS_AGE_KEY_FILE or GARAGE_ACCESS_KEY/GARAGE_SECRET_KEY}"
  : "${ARP_SECRETS_FILE:?Set ARP_SECRETS_FILE or GARAGE_ACCESS_KEY/GARAGE_SECRET_KEY}"
  command -v sops >/dev/null || {
    echo "sops is required to load Garage backup credentials" >&2
    exit 1
  }
  decrypted_secrets=$(mktemp)
  sops --decrypt --output-type json "$ARP_SECRETS_FILE" >"$decrypted_secrets"
  python3 - "$decrypted_secrets" "$secret_vars" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
out = {
    "garage_app_access_key": data.get("garage_app_access_key", ""),
    "garage_app_secret_key": data.get("garage_app_secret_key", ""),
}
if not out["garage_app_access_key"] or not out["garage_app_secret_key"]:
    raise SystemExit("decrypted runtime secrets do not contain Garage application credentials")
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    json.dump(out, handle)
PY
  rm -f "$decrypted_secrets"
  decrypted_secrets=
fi
chmod 0600 "$secret_vars"

echo "M11_CHECKPOINT_ID=$checkpoint_id"

gate_output=$(run_gate enable)
printf '%s\n' "$gate_output"
gate_enabled=true
grep -Fq 'M11_MUTATION_GATE=ENABLED' <<<"$gate_output" || {
  echo "mutation gate enable did not return the expected state" >&2
  exit 1
}

ssh_node "$app_ip" sudo systemctl stop arp
app_stopped=true
stopped_state=$(ssh_node "$app_ip" systemctl is-active arp || true)
[[ $stopped_state == inactive ]] || {
  echo "arp.service did not reach inactive state: $stopped_state" >&2
  exit 1
}
echo "M11_CHECKPOINT_APP_STATE=INACTIVE"

counts_before=$(attachment_counts)
IFS='|' read -r pending_before delete_pending_before available_before failed_before total_before <<<"$counts_before"
printf 'M11_CHECKPOINT_ATTACHMENT_COUNTS_BEFORE=pending:%s,delete_pending:%s,available:%s,failed:%s,total:%s\n' \
  "$pending_before" "$delete_pending_before" "$available_before" "$failed_before" "$total_before"

[[ $pending_before == 0 ]] || {
  echo "checkpoint requires attachment PENDING=0, found $pending_before" >&2
  exit 1
}
[[ $delete_pending_before == 0 ]] || {
  echo "checkpoint requires attachment DELETE_PENDING=0, found $delete_pending_before" >&2
  exit 1
}

freeze_start=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
echo "M11_CHECKPOINT_FREEZE_START=$freeze_start"

echo "M11_CHECKPOINT_PGBACKREST_BEGIN"
ssh_node "$backup_ip" sudo bash -s < "$root/scripts/backup/run-pgbackrest-full.sh"
echo "M11_CHECKPOINT_PGBACKREST_END"

ANSIBLE_HOST_KEY_CHECKING=True ansible-playbook \
  -i "$inventory_yml" \
  "$root/scripts/backup/m11-object-backup.yml" \
  --extra-vars "@$secret_vars" \
  --extra-vars "m11_checkpoint_id=$checkpoint_id" \
  --extra-vars "m11_garage_endpoint=$garage_endpoint" \
  --extra-vars "m11_garage_bucket=$garage_bucket"

object_root="/srv/backup/objects/checkpoints/$checkpoint_id/data"
manifest_path="/srv/backup/objects/checkpoints/$checkpoint_id/manifest.json"
verify_output=$(
  ssh_node "$backup_ip" sudo -u pgbackrest \
    /usr/bin/python3 /usr/local/lib/arp/verify_object_backup.py \
    --root "$object_root" --manifest "$manifest_path"
)
printf '%s\n' "$verify_output"
grep -Fq 'M11_OBJECT_BACKUP_VERIFY=PASS' <<<"$verify_output" || {
  echo "checkpoint object-backup verification did not pass" >&2
  exit 1
}

counts_after=$(attachment_counts)
printf 'M11_CHECKPOINT_ATTACHMENT_COUNTS_AFTER=%s\n' "$counts_after"
[[ $counts_after == "$counts_before" ]] || {
  echo "attachment lifecycle counts changed while application mutations were frozen" >&2
  exit 1
}

backup_verified_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
echo "M11_CHECKPOINT_BACKUP_VERIFIED_AT=$backup_verified_at"
echo "M11_CHECKPOINT_MANIFEST=$manifest_path"

ssh_node "$app_ip" sudo systemctl start arp
wait_app_health
app_stopped=false
echo "M11_CHECKPOINT_APP_STATE=HEALTHY"

disable_output=$(run_gate disable)
printf '%s\n' "$disable_output"
gate_enabled=false
grep -Fq 'M11_MUTATION_GATE=DISABLED' <<<"$disable_output" || {
  echo "mutation gate disable did not return the expected state" >&2
  exit 1
}

final_gate=$(run_gate status)
printf '%s\n' "$final_gate"
grep -Fq 'M11_MUTATION_GATE=DISABLED' <<<"$final_gate" || {
  echo "mutation gate is not disabled after checkpoint" >&2
  exit 1
}

writes_resumed_at=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
echo "M11_CHECKPOINT_WRITES_RESUMED_AT=$writes_resumed_at"
echo "M11_CHECKPOINT=PASS checkpoint_id=$checkpoint_id"
