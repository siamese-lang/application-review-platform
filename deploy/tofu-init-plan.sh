#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel)
runtime_root="$root/infra/opentofu"
: "${ARP_TOFU_STATE_PATH:?Set ARP_TOFU_STATE_PATH to a controlled runtime state path outside Git}"
state_path=$ARP_TOFU_STATE_PATH
[[ $state_path == /* && ! -d $state_path ]] || { echo 'ARP_TOFU_STATE_PATH must be an absolute file path.' >&2; exit 1; }
case "$state_path" in "$root"|"$root"/*) echo 'Runtime state must be outside the Git checkout.' >&2; exit 1;; esac
if [[ ! -e $state_path && ${ARP_RUNTIME_ABSENCE_VERIFIED:-} != yes ]]; then
  echo 'No retained runtime state found. Set ARP_RUNTIME_ABSENCE_VERIFIED=yes only after the live read-only preflight proves all old runtime nodes absent.' >&2
  exit 1
fi
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
plan_path=${ARP_TOFU_PLAN_PATH:-"${state_path%/*}/m6-runtime.tfplan"}
[[ $plan_path == /* && $plan_path != "$root" && $plan_path != "$root"/* ]] || { echo 'Runtime plan must use an absolute path outside Git.' >&2; exit 1; }
tofu -chdir="$runtime_root" plan -out="$plan_path" "$@"
echo "Plan created at $plan_path using local state $state_path. Review it manually; no apply was run."
