#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
vars="$root/config/ansible/group_vars/all/main.yml"
tasks="$root/config/ansible/roles/alloy/tasks/main.yml"
unit="$root/config/ansible/roles/alloy/templates/alloy.service.j2"
config="$root/monitoring/alloy/config.alloy"

grep -Fq 'alloy_version: 1.18.1' "$vars"
grep -Fq 'alloy_linux_amd64_sha256: fac853cbc3983a50a2368f9a685b31f74392ae86dd6155461b11a911c07b483c' "$vars"
grep -Fq 'alloy_memory_limit: 256M' "$vars"
grep -Fq 'alloy_cpu_quota: 25%' "$vars"

grep -Fq 'checksum: "sha256:{{ alloy_linux_amd64_sha256 }}"' "$tasks"
grep -Fq 'alloy-linux-amd64.zip' "$tasks"
grep -Fq '/etc/alloy/config.alloy' "$tasks"

grep -Fq -- '--server.http.listen-addr=127.0.0.1:12345' "$unit"
grep -Fq -- '--storage.path=/var/lib/alloy' "$unit"
grep -Fq -- '--disable-reporting' "$unit"
grep -Fq 'MemoryMax={{ alloy_memory_limit }}' "$unit"
grep -Fq 'CPUQuota={{ alloy_cpu_quota }}' "$unit"

grep -Fq 'logging {' "$config"
grep -Fq 'level  = "info"' "$config"
grep -Fq 'format = "logfmt"' "$config"

if grep -Eq '0\.0\.0\.0:12345|latest' "$config" "$unit" "$tasks" "$vars"; then
  echo 'Alloy baseline must keep its UI private and version-pinned.' >&2
  exit 1
fi

echo 'M7 Alloy repository contract: PASS'
