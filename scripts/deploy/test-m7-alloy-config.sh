#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
vars="$root/config/ansible/group_vars/all/main.yml"
site="$root/config/ansible/site.yml"
tasks="$root/config/ansible/roles/alloy/tasks/main.yml"
unit="$root/config/ansible/roles/alloy/templates/alloy.service.j2"
config="$root/monitoring/alloy/config.alloy"
edge_probe="$root/monitoring/alloy/edge-probe.alloy"

grep -Fq 'alloy_version: 1.18.1' "$vars"
grep -Fq 'alloy_linux_amd64_sha256: fac853cbc3983a50a2368f9a685b31f74392ae86dd6155461b11a911c07b483c' "$vars"
grep -Fq 'alloy_memory_limit: 256M' "$vars"
grep -Fq 'alloy_cpu_quota: 25%' "$vars"

grep -Fq 'checksum: "sha256:{{ alloy_linux_amd64_sha256 }}"' "$tasks"
grep -Fq 'alloy-linux-amd64.zip' "$tasks"
grep -Fq 'Ensure extracted Alloy binary is executable' "$tasks"
grep -Fq "mode: '0755'" "$tasks"
grep -Fq '/etc/alloy/config.alloy' "$tasks"
grep -Fq '/etc/alloy/edge-probe.alloy' "$tasks"
grep -Fq "alloy_node_role == 'edge'" "$tasks"
grep -Fq "alloy_node_role != 'edge'" "$tasks"
grep -Fq '/etc/alloy/postgres.alloy' "$tasks"
grep -Fq '/etc/alloy/secrets/postgres-monitor-password' "$tasks"
grep -Fq 'alloy_node_role == '\''db'\''' "$tasks"
grep -Fq 'alloy_node_role != '\''db'\''' "$tasks"
grep -Fq "else 'observability' if 'observability' in group_names" "$tasks"
grep -Fq "alloy_node_role != 'unsupported'" "$tasks"

grep -Fq -- '--server.http.listen-addr=127.0.0.1:12345' "$unit"
grep -Fq -- '--storage.path=/var/lib/alloy' "$unit"
grep -Fq -- '--disable-reporting' "$unit"
grep -Fq '  /etc/alloy' "$unit"
grep -Fq 'MemoryMax={{ alloy_memory_limit }}' "$unit"
grep -Fq 'CPUQuota={{ alloy_cpu_quota }}' "$unit"
grep -Fq 'Environment="ARP_ALLOY_NODE={{ inventory_hostname }}"' "$unit"
grep -Fq 'Environment="ARP_ALLOY_ROLE={{ alloy_node_role }}"' "$unit"
grep -Fq 'ARP_PROMETHEUS_REMOTE_WRITE_URL=http://{{ observability_private_ip }}:9090/api/v1/write' "$unit"

grep -Fq 'logging {' "$config"
grep -Fq 'level  = "info"' "$config"
grep -Fq 'format = "logfmt"' "$config"
grep -Fq 'prometheus.exporter.unix "host"' "$config"
grep -Fq 'prometheus.scrape "host"' "$config"
grep -Fq 'prometheus.remote_write "central"' "$config"
grep -Fq 'scrape_interval = "15s"' "$config"
grep -Fq 'node        = sys.env("ARP_ALLOY_NODE")' "$config"
grep -Fq 'role        = sys.env("ARP_ALLOY_ROLE")' "$config"
grep -Fq 'url = sys.env("ARP_PROMETHEUS_REMOTE_WRITE_URL")' "$config"
grep -Fq 'ARP_LOKI_PUSH_URL=http://{{ observability_private_ip }}:3100/loki/api/v1/push' "$unit"
grep -Fq 'ARP_TEMPO_OTLP_HTTP_ENDPOINT=http://{{ observability_private_ip }}:4318' "$unit"

grep -Fq 'prometheus.exporter.blackbox "application"' "$edge_probe"
grep -Fq 'name    = "application-api"' "$edge_probe"
grep -Fq 'address = "https://127.0.0.1/api/v1/programs?size=1"' "$edge_probe"
grep -Fq 'insecure_skip_verify: true' "$edge_probe"
grep -Fq 'discovery.relabel "application_probe"' "$edge_probe"
grep -Fq 'prometheus.scrape "application_probe"' "$edge_probe"
grep -Fq 'forward_to      = [prometheus.remote_write.central.receiver]' "$edge_probe"

test "$(grep -Ec 'roles: \[[^]]*alloy[^]]*\]' "$site")" -eq 5
grep -Fq 'roles: [ops]' "$site"

if grep -Eq '0\.0\.0\.0:12345|latest' "$config" "$unit" "$tasks" "$vars"; then
  echo 'Alloy baseline must keep its UI private and version-pinned.' >&2
  exit 1
fi

echo 'M7 Alloy repository contract: PASS'
