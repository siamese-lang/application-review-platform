#!/usr/bin/env bash
set -euo pipefail
umask 077

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
inventory_file=$(mktemp)
trap 'rm -f "$inventory_file"' EXIT

tofu -chdir="$root/infra/opentofu" output -json inventory \
  | "$root/deploy/generate-inventory.py" \
  >"$inventory_file"

cd "$root/config/ansible"
"$root/deploy/with-oslogin-ssh.py" -- \
  ansible-playbook -i "$inventory_file" m11-backup-closeout.yml
