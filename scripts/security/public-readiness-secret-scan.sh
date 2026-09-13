#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

image="ghcr.io/gitleaks/gitleaks:v8.29.1"
report_dir="$(mktemp -d "${TMPDIR:-/tmp}/arp-gitleaks.XXXXXX")"
history_report="$report_dir/history.json"
trap 'rm -rf "$report_dir"' EXIT

docker pull "$image" >/dev/null

set +e

docker run --rm   -v "$root:/repo:ro"   -v "$report_dir:/reports"   "$image"   git   --config /repo/.gitleaks.toml   --redact   --report-format json   --report-path /reports/history.json   /repo
history_rc=$?

set -e

history_count="$(jq 'length' "$history_report" 2>/dev/null || printf '0')"

printf 'history scan exit code: %s\n' "$history_rc"
printf 'history findings: %s\n' "$history_count"

if [[ "$history_rc" -ne 0 ]]; then
  printf '\n=== REDACTED HISTORY FINDING SUMMARY ===\n'
  jq -r '.[] | [.RuleID, .File, (.Commit // "-"), (.StartLine|tostring)] | @tsv'     "$history_report" | sort -u
  exit 1
fi

printf '\nPUBLIC READINESS SECRET SCAN: PASS\n'
