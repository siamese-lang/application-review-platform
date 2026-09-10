#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel)
cd "$root/infra/opentofu"
tofu init
# Planning is explicit and writes an ignored, reviewable binary plan. This script never applies it.
tofu plan -out=m4.tfplan "$@"
echo 'Plan created at infra/opentofu/m4.tfplan. Review it manually; no apply was run.'
