#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
vars="$root/config/ansible/group_vars/all/main.yml"
site="$root/config/ansible/site.yml"
tasks="$root/config/ansible/roles/tempo/tasks/main.yml"
config="$root/monitoring/tempo/tempo.yml"

grep -Fq 'tempo_image: grafana/tempo:3.0.2' "$vars"
grep -Fq 'tempo_memory_limit: 1536m' "$vars"
grep -Fq 'tempo_cpu_limit: 1.0' "$vars"
grep -Eq 'roles: \[[^]]*tempo[^]]*\]' "$site"

grep -Fq 'image: "{{ tempo_image }}"' "$tasks"
grep -Fq 'memory: "{{ tempo_memory_limit }}"' "$tasks"
grep -Fq 'cpus: "{{ tempo_cpu_limit }}"' "$tasks"
grep -Fq '/srv/observability/tempo:/var/tempo' "$tasks"
grep -Fq 'command: -target=all -config.file=/etc/tempo/tempo.yml' "$tasks"

grep -Fq 'http_listen_address: 127.0.0.1' "$config"
grep -Fq 'grpc_listen_address: 127.0.0.1' "$config"
grep -Fq 'grpc_listen_port: 9096' "$config"
grep -Fq 'endpoint: "10.40.0.60:4317"' "$config"
grep -Fq 'endpoint: "10.40.0.60:4318"' "$config"
grep -Fq 'backend: local' "$config"
grep -Fq 'path: /var/tempo/wal' "$config"
grep -Fq 'path: /var/tempo/blocks' "$config"
test "$(grep -Fc 'block_retention: 24h' "$config")" -eq 2
grep -Fq 'reporting_enabled: false' "$config"

if grep -Eq '0\.0\.0\.0|latest' "$config" "$tasks" "$vars"; then
  echo 'Tempo baseline must stay private and version-pinned.' >&2
  exit 1
fi

echo 'M7 Tempo repository contract: PASS'
