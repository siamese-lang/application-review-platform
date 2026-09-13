#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

image="ghcr.io/gitleaks/gitleaks:v8.29.1"
history_report="${TMPDIR:-/tmp}/arp-gitleaks-history.json"
current_report="${TMPDIR:-/tmp}/arp-gitleaks-current.json"

rm -f "$history_report" "$current_report"

docker pull "$image" >/dev/null

set +e

docker run --rm \
  -v "$root:/repo:ro" \
  -v "${TMPDIR:-/tmp}:/reports" \
  "$image" \
  git --redact \
  --report-format json \
  --report-path "/reports/$(basename "$history_report")" \
  /repo
history_rc=$?

docker run --rm \
  -v "$root:/repo:ro" \
  -v "${TMPDIR:-/tmp}:/reports" \
  "$image" \
  dir --redact \
  --report-format json \
  --report-path "/reports/$(basename "$current_report")" \
  /repo
current_rc=$?

set -e

history_count="$(jq 'length' "$history_report" 2>/dev/null || printf '0')"
current_count="$(jq 'length' "$current_report" 2>/dev/null || printf '0')"

printf 'history scan exit code: %s\n' "$history_rc"
printf 'current tree exit code: %s\n' "$current_rc"
printf 'history findings: %s\n' "$history_count"
printf 'current-tree findings: %s\n' "$current_count"

if [[ "$history_rc" -ne 0 ]]; then
  printf '\n=== REDACTED HISTORY FINDING SUMMARY ===\n'
  jq -r '.[] | [.RuleID, .File, (.Commit // "-"), (.StartLine|tostring)] | @tsv' \
    "$history_report" | sort -u
fi

if [[ "$current_rc" -ne 0 ]]; then
  printf '\n=== REDACTED CURRENT-TREE FINDING SUMMARY ===\n'
  jq -r '.[] | [.RuleID, .File, "-", (.StartLine|tostring)] | @tsv' \
    "$current_report" | sort -u
fi

if [[ "$history_rc" -ne 0 || "$current_rc" -ne 0 ]]; then
  exit 1
fi

printf '\nPUBLIC READINESS SECRET SCAN: PASS\n'
