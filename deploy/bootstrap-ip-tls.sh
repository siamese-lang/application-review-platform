#!/usr/bin/env bash
set -euo pipefail
umask 077
root=$(git rev-parse --show-toplevel)
: "${ACME_EMAIL:?Set the Lets Encrypt account email address}"

if [[ -z ${ARP_OSLOGIN_USER:-} || -z ${ARP_OSLOGIN_SSH_KEY:-} || -z ${ARP_OSLOGIN_KNOWN_HOSTS:-} ]]; then
  exec "$root/deploy/with-oslogin-ssh.py" -- "$0" "$@"
fi

for command in tofu python3 ssh ansible-playbook sudo; do
  command -v "$command" >/dev/null || { echo "Missing prerequisite: $command" >&2; exit 1; }
done

tofu_cmd=(tofu)
if [[ $EUID -ne 0 ]]; then
  tofu_cmd=(sudo -n tofu)
fi

edge_public_ip=$("${tofu_cmd[@]}" -chdir="$root/infra/opentofu" output -raw edge_public_ip)
edge_private_ip=$(
  "${tofu_cmd[@]}" -chdir="$root/infra/opentofu" output -json inventory |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["edge-01"]["private_ip"])'
)
python3 - "$edge_public_ip" "$edge_private_ip" <<'PY'
import ipaddress, sys
public = ipaddress.ip_address(sys.argv[1])
private = ipaddress.ip_address(sys.argv[2])
if public.version != 4 or public.is_private:
    raise SystemExit(f"edge public address is not a public IPv4 address: {public}")
if private.version != 4 or not private.is_private:
    raise SystemExit(f"edge private address is not a private IPv4 address: {private}")
PY

ssh_cmd=(
  ssh
  -i "$ARP_OSLOGIN_SSH_KEY"
  -o "UserKnownHostsFile=$ARP_OSLOGIN_KNOWN_HOSTS"
  -o StrictHostKeyChecking=yes
  -o IdentitiesOnly=yes
  "$ARP_OSLOGIN_USER@$edge_private_ip"
)

"${ssh_cmd[@]}" sudo /opt/arp-certbot/bin/certbot certonly \
  --non-interactive --agree-tos --no-eff-email \
  --email "$ACME_EMAIL" \
  --preferred-profile shortlived \
  --webroot --webroot-path /var/lib/acme \
  --ip-address "$edge_public_ip"

"${ssh_cmd[@]}" sudo ln -sfn "/etc/letsencrypt/live/$edge_public_ip/fullchain.pem" /etc/nginx/tls/fullchain.pem
"${ssh_cmd[@]}" sudo ln -sfn "/etc/letsencrypt/live/$edge_public_ip/privkey.pem" /etc/nginx/tls/privkey.pem

cd "$root/config/ansible"
ansible-playbook site.yml --limit edge

"${ssh_cmd[@]}" sudo /usr/sbin/nginx -t
"${ssh_cmd[@]}" sudo /opt/arp-certbot/bin/certbot certificates

echo "PASS: public IP certificate is installed for https://$edge_public_ip and automatic renewal is enabled."
