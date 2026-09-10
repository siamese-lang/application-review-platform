#!/usr/bin/env bash
set -euo pipefail
umask 077
root=$(git rev-parse --show-toplevel)
: "${SYNTHETIC_APPLICANT_PASSWORD:?required}"
: "${SYNTHETIC_REVIEWER_PASSWORD:?required}"
: "${SYNTHETIC_ADMIN_PASSWORD:?required}"

if [[ -z ${ARP_OSLOGIN_USER:-} || -z ${ARP_OSLOGIN_SSH_KEY:-} || -z ${ARP_OSLOGIN_KNOWN_HOSTS:-} ]]; then
  exec "$root/deploy/with-oslogin-ssh.py" -- "$0" "$@"
fi

for command in htpasswd tofu python3 ssh sudo; do
  command -v "$command" >/dev/null || { echo "Missing prerequisite: $command" >&2; exit 1; }
done

tofu_cmd=(tofu)
if [[ $EUID -ne 0 ]]; then
  tofu_cmd=(sudo -n tofu)
fi

db_ip=$(
  "${tofu_cmd[@]}" -chdir="$root/infra/opentofu" output -json inventory |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["db-01"]["private_ip"])'
)
python3 - "$db_ip" <<'PY'
import ipaddress, sys
ip = ipaddress.ip_address(sys.argv[1])
if ip.version != 4 or not ip.is_private:
    raise SystemExit(f"db-01 inventory address is not a private IPv4 address: {ip}")
PY

ssh_cmd=(
  ssh
  -i "$ARP_OSLOGIN_SSH_KEY"
  -o "UserKnownHostsFile=$ARP_OSLOGIN_KNOWN_HOSTS"
  -o StrictHostKeyChecking=yes
  -o IdentitiesOnly=yes
  "$ARP_OSLOGIN_USER@$db_ip"
)

sql=$(mktemp)
trap 'rm -f "$sql"' EXIT
for role in APPLICANT REVIEWER ADMIN; do
  var="SYNTHETIC_${role}_PASSWORD"
  password=${!var}
  username="m4-${role,,}"
  hash=$(htpasswd -bnBC 12 '' "$password" | tr -d ':\n')
  escaped_hash=${hash//\'/\'\'}
  printf "INSERT INTO users (username, password_hash, role) SELECT '%s', '%s', '%s' WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = '%s');\n" \
    "$username" "$escaped_hash" "$role" "$username" >>"$sql"
done

"${ssh_cmd[@]}" sudo -u postgres env PGOPTIONS=--client-min-messages=warning \
  psql -d arp -v ON_ERROR_STOP=1 <"$sql" >/dev/null

echo 'Synthetic users are present; existing accounts were not rotated.'
