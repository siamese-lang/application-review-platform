#!/usr/bin/env bash
set -euo pipefail
for command in tofu python3 ansible-playbook ansible-galaxy sops age git java; do
  command -v "$command" >/dev/null || { echo "Missing prerequisite: $command" >&2; exit 1; }
done
[[ $(git rev-parse --abbrev-ref HEAD) == codex/implement-m4-cloud-deployment ]] || echo 'Warning: verify the intended branch and exact commit before Phase 2.' >&2
cat <<'MSG'
Prerequisites found. This script performs no authentication and no GCP mutation.
Owner bootstrap must separately confirm billing/API readiness and account-specific IAP/OS Login IAM.
MSG
