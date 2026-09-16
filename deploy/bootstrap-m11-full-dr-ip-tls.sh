#!/usr/bin/env bash
set -euo pipefail
umask 077

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${ACME_EMAIL:?Set the Let's Encrypt account email address}"

if [[ -z ${ARP_OSLOGIN_USER:-} || -z ${ARP_OSLOGIN_SSH_KEY:-} || -z ${ARP_OSLOGIN_KNOWN_HOSTS:-} ]]; then
  exec "$root/deploy/with-oslogin-ssh.py" -- "$0" "$@"
fi

for command in tofu python3 ssh ansible-playbook curl; do
  command -v "$command" >/dev/null || {
    echo "Missing prerequisite: $command" >&2
    exit 1
  }
done

tofu_cmd=(tofu)
if [[ $EUID -ne 0 ]]; then
  tofu_cmd=(sudo -n tofu)
fi

full_dr=$("${tofu_cmd[@]}" -chdir="$root/infra/opentofu" output -json full_dr)
full_dr_inventory=$("${tofu_cmd[@]}" -chdir="$root/infra/opentofu" output -json full_dr_inventory)

read -r edge_public_ip edge_private_ip < <(
  python3 - "$full_dr" <<'PY'
import ipaddress
import json
import sys

data = json.loads(sys.argv[1])
if not data:
    raise SystemExit("full DR output is disabled")
nodes = data.get("nodes", {})
expected = {
    "dr-edge-01",
    "dr-app-01",
    "dr-db-01",
    "dr-storage-01",
    "dr-storage-02",
    "dr-storage-03",
}
if set(nodes) != expected:
    raise SystemExit(f"unexpected full DR node set: {sorted(nodes)}")
public = ipaddress.ip_address(data["edge_public_ip"])
private = ipaddress.ip_address(nodes["dr-edge-01"]["private_ip"])
if public.version != 4 or public.is_private:
    raise SystemExit(f"DR edge public address is not a public IPv4 address: {public}")
if private.version != 4 or not private.is_private:
    raise SystemExit(f"DR edge private address is not a private IPv4 address: {private}")
print(public, private)
PY
)

inventory_file=$(mktemp /tmp/m11-full-dr-edge-https.XXXXXX.yml)
trap 'rm -f "$inventory_file"' EXIT
printf '%s\n' "$full_dr_inventory" | "$root/deploy/generate-inventory.py" >"$inventory_file"

ssh_cmd=(
  ssh
  -i "$ARP_OSLOGIN_SSH_KEY"
  -o "UserKnownHostsFile=$ARP_OSLOGIN_KNOWN_HOSTS"
  -o StrictHostKeyChecking=yes
  -o IdentitiesOnly=yes
  "$ARP_OSLOGIN_USER@$edge_private_ip"
)

"${ssh_cmd[@]}" sudo /opt/arp-certbot/bin/certbot certonly   --non-interactive --agree-tos --no-eff-email   --email "$ACME_EMAIL"   --preferred-profile shortlived   --webroot --webroot-path /var/lib/acme   --ip-address "$edge_public_ip"

"${ssh_cmd[@]}" sudo ln -sfn "/etc/letsencrypt/live/$edge_public_ip/fullchain.pem" /etc/nginx/tls/fullchain.pem
"${ssh_cmd[@]}" sudo ln -sfn "/etc/letsencrypt/live/$edge_public_ip/privkey.pem" /etc/nginx/tls/privkey.pem

cd "$root/config/ansible"
ansible-playbook --inventory "$inventory_file" full-dr-edge-https.yml

"${ssh_cmd[@]}" sudo /usr/sbin/nginx -t
"${ssh_cmd[@]}" sudo /opt/arp-certbot/bin/certbot certificates

curl --fail --silent --show-error --connect-timeout 10 --max-time 30   "https://$edge_public_ip/api/v1/programs?size=1" >/dev/null

echo "M11_FULL_DR_HTTPS_URL=https://$edge_public_ip"
echo "M11_FULL_DR_HTTPS=PASS"
