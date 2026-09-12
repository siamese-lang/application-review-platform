#!/usr/bin/env bash
set -euo pipefail
umask 077

root=$(git rev-parse --show-toplevel)
# Keep the final M6 configuration entry point separate from the legacy M4
# working-tree/local-JAR compatibility path.
unset ARP_APP_JAR ARP_APP_VERSION
: "${SOPS_AGE_KEY_FILE:?Point to the age private key outside the repository on ops-01}"
: "${ARP_SECRETS_FILE:?Point to committed SOPS-encrypted runtime YAML}"
if [[ -n ${ARP_TLS_CERTIFICATE:-} || -n ${ARP_TLS_PRIVATE_KEY:-} ]]; then
  : "${ARP_TLS_CERTIFICATE:?Set both ARP_TLS_CERTIFICATE and ARP_TLS_PRIVATE_KEY}"
  : "${ARP_TLS_PRIVATE_KEY:?Set both ARP_TLS_CERTIFICATE and ARP_TLS_PRIVATE_KEY}"
fi

secret_vars=$(mktemp)
trap 'rm -f "$secret_vars"' EXIT
sops --decrypt "$ARP_SECRETS_FILE" >"$secret_vars"
cd "$root/config/ansible"
ansible-galaxy collection install -r requirements.yml
"$root/deploy/with-oslogin-ssh.py" -- ansible-playbook site.yml --extra-vars "@$secret_vars"
