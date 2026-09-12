#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
: "${ARP_RELEASE_BUNDLE_DIR:?Set the exact local release bundle directory on ops-01}"
: "${ARP_RELEASE_SHA:?Set the full lowercase 40-character release source SHA}"
[[ $ARP_RELEASE_SHA =~ ^[0-9a-f]{40}$ ]] || { echo 'ARP_RELEASE_SHA must be a full lowercase 40-character Git SHA.' >&2; exit 1; }
bundle_dir=$(realpath "$ARP_RELEASE_BUNDLE_DIR")

bash "$root/scripts/release/verify-release-bundle.sh" "$bundle_dir" "$ARP_RELEASE_SHA"
release_vars=$(mktemp)
trap 'rm -f "$release_vars"' EXIT
python3 - "$bundle_dir" "$ARP_RELEASE_SHA" >"$release_vars" <<'PY'
import json
import sys

json.dump({"arp_release_bundle_dir": sys.argv[1], "arp_release_sha": sys.argv[2]}, sys.stdout)
PY
cd "$root/config/ansible"
"$root/deploy/with-oslogin-ssh.py" -- ansible-playbook release.yml \
  --extra-vars "@$release_vars"
