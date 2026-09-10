#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel)
runtime_root="$root/infra/opentofu"
state_path=${ARP_TOFU_STATE_PATH:-"$runtime_root/terraform.tfstate"}
mkdir -p "$(dirname "$state_path")"
tofu -chdir="$runtime_root" init -reconfigure -backend-config="path=$state_path"
# Planning is explicit and writes an ignored, reviewable binary plan. This script never applies it.
tofu -chdir="$runtime_root" plan -out=m4.tfplan "$@"
echo "Plan created at infra/opentofu/m4.tfplan using local state $state_path. Review it manually; no apply was run."
