#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${ARP_ROLLBACK_SHA:?Set the explicit full lowercase 40-character rollback target SHA}"
[[ $ARP_ROLLBACK_SHA =~ ^[0-9a-f]{40}$ ]] || { echo 'ARP_ROLLBACK_SHA must be a full lowercase 40-character Git SHA.' >&2; exit 1; }
[[ ${ARP_ROLLBACK_SCHEMA_COMPATIBLE:-} == true ]] || {
  echo 'Set ARP_ROLLBACK_SCHEMA_COMPATIBLE=true only after establishing schema compatibility; no database rollback is performed.' >&2
  exit 1
}

rollback_vars=$(mktemp)
trap 'rm -f "$rollback_vars"' EXIT
python3 - "$ARP_ROLLBACK_SHA" >"$rollback_vars" <<'PY'
import json
import sys

json.dump({"arp_rollback_sha": sys.argv[1], "arp_rollback_schema_compatible": True}, sys.stdout)
PY
cd "$root/config/ansible"
"$root/deploy/with-oslogin-ssh.py" -- ansible-playbook rollback.yml \
  --extra-vars "@$rollback_vars"
