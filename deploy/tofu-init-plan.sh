#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel)
runtime_root="$root/infra/opentofu"
state_path=${ARP_TOFU_STATE_PATH:-"$runtime_root/terraform.tfstate"}
mkdir -p "$(dirname "$state_path")"

if [[ -e "$state_path" && ! -s "$state_path" ]]; then
  echo "Refusing to plan with an empty runtime state file: $state_path" >&2
  echo 'Restore the last known-good runtime state before continuing.' >&2
  exit 1
fi

# Initialize idempotently against the requested local state path. Do not use
# -reconfigure here: repeated planning must never discard an existing backend
# configuration or bypass state-migration safeguards.
tofu -chdir="$runtime_root" init -lockfile=readonly -backend-config="path=$state_path"

# Planning is explicit and writes an ignored, reviewable binary plan. This script never applies it.
tofu -chdir="$runtime_root" plan -out=m4.tfplan "$@"
echo "Plan created at infra/opentofu/m4.tfplan using local state $state_path. Review it manually; no apply was run."
