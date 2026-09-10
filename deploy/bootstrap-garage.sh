#!/usr/bin/env bash
set -euo pipefail
# Run on ops-01 through deploy/with-oslogin-ssh.py after the Garage role.
: "${GARAGE_APP_ACCESS_KEY:?required}"
: "${GARAGE_APP_SECRET_KEY:?required}"
: "${ARP_OSLOGIN_USER:?run this script through deploy/with-oslogin-ssh.py}"
: "${ARP_OSLOGIN_SSH_KEY:?run this script through deploy/with-oslogin-ssh.py}"
: "${ARP_OSLOGIN_KNOWN_HOSTS:?run this script through deploy/with-oslogin-ssh.py}"
[[ $GARAGE_APP_ACCESS_KEY =~ ^GK[0-9a-f]{24}$ ]] || { echo 'GARAGE_APP_ACCESS_KEY must be GK followed by 24 lowercase hex characters.' >&2; exit 1; }
[[ $GARAGE_APP_SECRET_KEY =~ ^[0-9a-f]{64}$ ]] || { echo 'GARAGE_APP_SECRET_KEY must be 64 lowercase hex characters.' >&2; exit 1; }

root=$(git rev-parse --show-toplevel)
GARAGE_LAYOUT_CAPACITY=${GARAGE_LAYOUT_CAPACITY:-25G}
tofu_cmd=(tofu)
if [[ $EUID -ne 0 ]]; then
  tofu_cmd=(sudo -n tofu)
fi
inventory_json=$("${tofu_cmd[@]}" -chdir="$root/infra/opentofu" output -json inventory)

node_value() {
  local host=$1 field=$2
  python3 -c 'import json,sys; data=json.loads(sys.stdin.read()); print(data[sys.argv[1]][sys.argv[2]])' "$host" "$field" <<<"$inventory_json"
}

ssh_cmd=(
  ssh
  -i "$ARP_OSLOGIN_SSH_KEY"
  -o "UserKnownHostsFile=$ARP_OSLOGIN_KNOWN_HOSTS"
  -o StrictHostKeyChecking=yes
  -o IdentitiesOnly=yes
)
run() {
  local address=$1
  shift
  "${ssh_cmd[@]}" "$ARP_OSLOGIN_USER@$address" sudo docker exec garage /garage -c /etc/garage.toml "$@"
}

declare -A node_ip node_zone node_id
for host in storage-01 storage-02 storage-03; do
  node_ip[$host]=$(node_value "$host" private_ip)
  node_zone[$host]=$(node_value "$host" zone)
  node_id[$host]=$(run "${node_ip[$host]}" node id -q | cut -d@ -f1)
  [[ ${node_id[$host]} =~ ^[0-9a-f]{64}$ ]] || { echo "Invalid Garage node id for $host" >&2; exit 1; }
done

primary=storage-01
primary_ip=${node_ip[$primary]}
for host in storage-02 storage-03; do
  run "$primary_ip" node connect "${node_id[$host]}@${node_ip[$host]}:3901"
done

layout=$(run "$primary_ip" layout show)
needs_layout=false
for host in storage-01 storage-02 storage-03; do
  short_id=${node_id[$host]:0:16}
  if ! grep -Fq "$short_id" <<<"$layout"; then
    needs_layout=true
    break
  fi
done

if [[ $needs_layout == true ]]; then
  for host in storage-01 storage-02 storage-03; do
    # Keep the positional node ID before --tag because Garage's --tag accepts one or more values.
    run "$primary_ip" layout assign "${node_id[$host]}" -z "${node_zone[$host]}" -c "$GARAGE_LAYOUT_CAPACITY" -t "$host"
  done
  current_version=$(run "$primary_ip" layout show | sed -n 's/^Current cluster layout version: \([0-9][0-9]*\)$/\1/p' | head -1)
  [[ -n $current_version ]] || { echo 'Could not determine current Garage layout version.' >&2; exit 1; }
  run "$primary_ip" layout apply --version "$((current_version + 1))"
fi

run "$primary_ip" bucket info application-review >/dev/null 2>&1 || run "$primary_ip" bucket create application-review
if ! run "$primary_ip" key info "$GARAGE_APP_ACCESS_KEY" >/dev/null 2>&1; then
  run "$primary_ip" key import --name arp-application --yes "$GARAGE_APP_ACCESS_KEY" "$GARAGE_APP_SECRET_KEY"
fi
run "$primary_ip" bucket allow --read --write --owner application-review --key "$GARAGE_APP_ACCESS_KEY"
