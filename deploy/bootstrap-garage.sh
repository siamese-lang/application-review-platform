#!/usr/bin/env bash
set -euo pipefail
# Run on ops-01 through deploy/with-oslogin-ssh.py after the Garage role.
: "${GARAGE_RPC_SECRET:?required}"
: "${GARAGE_APP_ACCESS_KEY:?required}"
: "${GARAGE_APP_SECRET_KEY:?required}"
: "${ARP_OSLOGIN_USER:?run this script through deploy/with-oslogin-ssh.py}"
: "${ARP_OSLOGIN_SSH_KEY:?run this script through deploy/with-oslogin-ssh.py}"
: "${ARP_OSLOGIN_KNOWN_HOSTS:?run this script through deploy/with-oslogin-ssh.py}"

ssh_cmd=(
  ssh
  -i "$ARP_OSLOGIN_SSH_KEY"
  -o "UserKnownHostsFile=$ARP_OSLOGIN_KNOWN_HOSTS"
  -o StrictHostKeyChecking=yes
  -o IdentitiesOnly=yes
)
run() {
  local host=$1
  shift
  "${ssh_cmd[@]}" "$ARP_OSLOGIN_USER@$host" sudo docker exec garage /garage -c /etc/garage.toml "$@"
}

primary=storage-01
for host in storage-02 storage-03; do
  node_id=$(run "$host" node id -q | cut -d@ -f1)
  run "$primary" node connect "$node_id@${host}:3901"
done
if ! run "$primary" layout show | grep -q 'storage-01'; then
  for item in 'storage-01 asia-northeast3-a' 'storage-02 asia-northeast3-b' 'storage-03 asia-northeast3-c'; do
    read -r host zone <<<"$item"
    node_id=$(run "$host" node id -q | cut -d@ -f1)
    run "$primary" layout assign -z "$zone" -c 30G "$node_id"
  done
  version=$(run "$primary" layout show | sed -n 's/.*apply --version \([0-9][0-9]*\).*/\1/p' | head -1)
  run "$primary" layout apply --version "$version"
fi
run "$primary" bucket info application-review >/dev/null 2>&1 || run "$primary" bucket create application-review
if ! run "$primary" key info "$GARAGE_APP_ACCESS_KEY" >/dev/null 2>&1; then
  run "$primary" key import "$GARAGE_APP_ACCESS_KEY" "$GARAGE_APP_SECRET_KEY" --name arp-application
fi
run "$primary" bucket allow --read --write --owner application-review --key "$GARAGE_APP_ACCESS_KEY"
