#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel)
bootstrap_root="$root/infra/opentofu/bootstrap"
: "${ARP_BOOTSTRAP_STATE_PATH:?Set ARP_BOOTSTRAP_STATE_PATH to the retained owner-bootstrap state outside Git}"
state_path=$ARP_BOOTSTRAP_STATE_PATH
[[ $state_path == /* && ! -d $state_path ]] || { echo 'ARP_BOOTSTRAP_STATE_PATH must be an absolute file path.' >&2; exit 1; }
case "$state_path" in "$root"|"$root"/*) echo 'Bootstrap state must be outside the Git checkout.' >&2; exit 1;; esac
[[ -s $state_path ]] || { echo 'Retained bootstrap state is missing or empty. STOP; reconcile/import retained resources before apply.' >&2; exit 1; }
plan_path=${ARP_BOOTSTRAP_PLAN_PATH:-"${state_path%/*}/m6-bootstrap.tfplan"}
[[ $plan_path == /* && $plan_path != "$root" && $plan_path != "$root"/* ]] || { echo 'Bootstrap plan must use an absolute path outside Git.' >&2; exit 1; }

tofu -chdir="$bootstrap_root" init -lockfile=readonly -backend-config="path=$state_path"
state_resources=$(tofu -chdir="$bootstrap_root" state list)
for retained in google_service_account.ops google_service_account.workload; do
  grep -Fxq "$retained" <<<"$state_resources" || { echo "Retained resource $retained is absent from bootstrap state. STOP for controlled reconciliation." >&2; exit 1; }
done
tofu -chdir="$bootstrap_root" plan -out="$plan_path" "$@"
echo "Bootstrap plan created at $plan_path using retained state $state_path. Review it manually; no apply was run."
