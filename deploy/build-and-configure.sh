#!/usr/bin/env bash
set -euo pipefail
umask 077
root=$(git rev-parse --show-toplevel)
: "${SOPS_AGE_KEY_FILE:?Point to the age private key outside the repository on ops-01}"
: "${ARP_TLS_CERTIFICATE:?Point to operator-provisioned certificate material}"
: "${ARP_TLS_PRIVATE_KEY:?Point to operator-provisioned private key material}"
: "${ARP_SECRETS_FILE:?Point to committed SOPS-encrypted runtime YAML}"
export ARP_APP_VERSION="$(git -C "$root" rev-parse --short=12 HEAD)"
(cd "$root" && ./mvnw -q -DskipTests package)
export ARP_APP_JAR
ARP_APP_JAR=$(find "$root/app/target" -maxdepth 1 -name '*.jar' ! -name '*.original' -print -quit)
secret_vars=$(mktemp)
trap 'rm -f "$secret_vars"' EXIT
sops --decrypt "$ARP_SECRETS_FILE" >"$secret_vars"
cd "$root/config/ansible"
ansible-galaxy collection install -r requirements.yml
"$root/deploy/with-oslogin-ssh.py" -- ansible-playbook site.yml --extra-vars "@$secret_vars"
