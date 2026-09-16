#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
export ARP_M10_R3B_MODE=retest
exec bash "$root/scripts/reliability/run-m10-r3b.sh" "$@"
