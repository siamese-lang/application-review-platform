#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
vars="$root/config/ansible/group_vars/all/main.yml"
site="$root/config/ansible/site.yml"
tasks="$root/config/ansible/roles/alertmanager/tasks/main.yml"
unit="$root/config/ansible/roles/alertmanager/templates/alertmanager.service.j2"
config="$root/monitoring/alertmanager/alertmanager.yml"
prometheus="$root/monitoring/prometheus/prometheus.yml"

grep -Fq 'alertmanager_version: 0.34.0' "$vars"
grep -Fq 'alertmanager_linux_amd64_sha256: 19c75a11d8c03dc4ade7abdbddfb3a8f28c9e7b000d0849cda0cd71dffd74a03' "$vars"
grep -Fq 'alertmanager_retention_time: 120h' "$vars"
grep -Fq 'alertmanager_memory_limit: 256M' "$vars"
grep -Fq 'alertmanager_cpu_quota: 25%' "$vars"
grep -Eq 'roles: \[[^]]*alertmanager[^]]*\]' "$site"

grep -Fq 'checksum: "sha256:{{ alertmanager_linux_amd64_sha256 }}"' "$tasks"
grep -Fq '/srv/observability/alertmanager' "$tasks"

grep -Fq -- '--web.listen-address={{ observability_private_ip }}:9093' "$unit"
grep -Fq -- '--cluster.listen-address=' "$unit"
grep -Fq -- '--data.retention={{ alertmanager_retention_time }}' "$unit"
grep -Fq 'MemoryMax={{ alertmanager_memory_limit }}' "$unit"
grep -Fq 'CPUQuota={{ alertmanager_cpu_quota }}' "$unit"

grep -Fq 'receiver: "null"' "$config"
grep -Fq 'repeat_interval: 4h' "$config"
grep -Fq '10.40.0.60:9093' "$prometheus"

if grep -Eq '0\.0\.0\.0:9093|latest' "$config" "$unit" "$tasks" "$vars" "$prometheus"; then
  echo 'Alertmanager baseline must stay private and version-pinned.' >&2
  exit 1
fi

echo 'M7 Alertmanager repository contract: PASS'
