#!/usr/bin/env bash
set -euo pipefail
for command in tofu python3 ansible-playbook ansible-galaxy sops age git java ssh ssh-keygen psql; do
  command -v "$command" >/dev/null || { echo "Missing prerequisite: $command" >&2; exit 1; }
done
branch=$(git rev-parse --abbrev-ref HEAD)
commit=$(git rev-parse HEAD)
printf 'Prerequisites found. Current revision: %s @ %s\n' "$branch" "$commit"
cat <<'MSG'
This script performs no authentication and no GCP mutation.
Before Phase 2, verify that this exact revision is the reviewed PR head.
Owner bootstrap must separately confirm billing/API readiness and account-specific IAP/OS Login IAM.
MSG
