#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

expected_version="8.29.1"
gitleaks_bin="${GITLEAKS_BIN:-}"
if [[ -z "$gitleaks_bin" ]]; then
  gitleaks_bin="$(command -v gitleaks || true)"
fi
if [[ -z "$gitleaks_bin" && -x /tmp/gitleaks ]]; then
  gitleaks_bin="/tmp/gitleaks"
fi
if [[ -z "$gitleaks_bin" || ! -x "$gitleaks_bin" ]]; then
  echo "gitleaks $expected_version is required; set GITLEAKS_BIN or install it in PATH." >&2
  exit 2
fi

version_output="$("$gitleaks_bin" version 2>/dev/null || true)"
if [[ "$version_output" != *"$expected_version"* ]]; then
  echo "Expected gitleaks $expected_version, got: $version_output" >&2
  exit 2
fi

report_dir="$(mktemp -d "${TMPDIR:-/tmp}/arp-gitleaks.XXXXXX")"
history_report="$report_dir/history.json"
trap 'rm -rf "$report_dir"' EXIT

set +e
"$gitleaks_bin" git \
  --config .gitleaks.toml \
  --redact \
  --report-format json \
  --report-path "$history_report" \
  .
history_rc=$?
set -e

history_count="$(jq 'length' "$history_report" 2>/dev/null || printf '0')"

printf 'history scan exit code: %s\n' "$history_rc"
printf 'history findings: %s\n' "$history_count"

if [[ "$history_rc" -ne 0 ]]; then
  printf '\n=== REDACTED HISTORY FINDING SUMMARY ===\n'
  jq -r '.[] | [.RuleID, .File, (.Commit // "-"), (.StartLine|tostring)] | @tsv' \
    "$history_report" | sort -u
  exit 1
fi

printf '\nPUBLIC READINESS SECRET SCAN: PASS\n'
