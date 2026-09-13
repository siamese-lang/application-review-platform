#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
vars="$root/config/ansible/group_vars/all/main.yml"
site="$root/config/ansible/site.yml"
tasks="$root/config/ansible/roles/loki/tasks/main.yml"
config="$root/monitoring/loki/loki.yml"

grep -Fq 'loki_image: grafana/loki:3.7.7' "$vars"
grep -Fq 'loki_memory_limit: 1g' "$vars"
grep -Fq 'loki_cpu_limit: 1.0' "$vars"
grep -Fq 'roles: [prometheus, loki]' "$site"

grep -Fq 'image: "{{ loki_image }}"' "$tasks"
grep -Fq 'memory: "{{ loki_memory_limit }}"' "$tasks"
grep -Fq 'cpus: "{{ loki_cpu_limit }}"' "$tasks"
grep -Fq '/srv/observability/loki:/var/lib/loki' "$tasks"

grep -Fq 'http_listen_address: 10.40.0.60' "$config"
grep -Fq 'grpc_listen_address: 127.0.0.1' "$config"
grep -Fq 'store: tsdb' "$config"
grep -Fq 'object_store: filesystem' "$config"
grep -Fq 'schema: v13' "$config"
grep -Fq 'period: 24h' "$config"
grep -Fq 'retention_period: 72h' "$config"
grep -Fq 'retention_enabled: true' "$config"
grep -Fq 'delete_request_store: filesystem' "$config"

if grep -Eq '0\.0\.0\.0|latest' "$config" "$tasks" "$vars"; then
  echo 'Loki baseline must stay private and version-pinned.' >&2
  exit 1
fi

echo 'M7 Loki repository contract: PASS'
