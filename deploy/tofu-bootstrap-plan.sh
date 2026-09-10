#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel)
bootstrap_root="$root/infra/opentofu/bootstrap"
cd "$bootstrap_root"
tofu init -lockfile=readonly
# Owner-controlled IAM/service-account bootstrap is a separate local state and is never handed to ops-01.
tofu plan -out=m4-bootstrap.tfplan "$@"
echo 'Bootstrap plan created at infra/opentofu/bootstrap/m4-bootstrap.tfplan. Review it manually; no apply was run.'
