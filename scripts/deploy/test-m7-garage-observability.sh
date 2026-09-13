#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
vars="$root/config/ansible/group_vars/all/main.yml"
schema="$root/config/secrets/runtime.schema.yaml"
garage_config="$root/config/ansible/roles/garage/templates/garage.toml.j2"
garage_tasks="$root/config/ansible/roles/garage/tasks/main.yml"
alloy_config="$root/monitoring/alloy/garage.alloy"
alloy_tasks="$root/config/ansible/roles/alloy/tasks/main.yml"
alloy_unit="$root/config/ansible/roles/alloy/templates/alloy.service.j2"

grep -Fq 'garage_image: dxflrs/garage:v2.4.1' "$vars"
grep -Fq 'garage_metrics_token: REQUIRED_RUNTIME_SECRET' "$schema"

grep -Fq '[admin]' "$garage_config"
grep -Fq 'api_bind_addr = "127.0.0.1:3903"' "$garage_config"
grep -Fq 'metrics_token = "{{ garage_metrics_token }}"' "$garage_config"
grep -Fq 'metrics_require_token = true' "$garage_config"

if grep -Eq '0\.0\.0\.0:3903|trace_sink|admin_token' "$garage_config"; then
  echo 'Garage observability must keep admin local, avoid admin credentials, and leave tracing disabled.' >&2
  exit 1
fi

grep -Fq 'log_driver: journald' "$garage_tasks"
grep -Fq 'tag: garage' "$garage_tasks"

grep -Fq 'content: "{{ garage_metrics_token }}"' "$alloy_tasks"
grep -Fq 'dest: /etc/alloy/secrets/garage-metrics-token' "$alloy_tasks"
grep -Fq 'dest: /etc/alloy/garage.alloy' "$alloy_tasks"
grep -Fq "when: alloy_node_role == 'storage'" "$alloy_tasks"
grep -Fq "when: alloy_node_role != 'storage'" "$alloy_tasks"
grep -Fq 'no_log: true' "$alloy_tasks"

grep -Eq "\{% elif alloy_node_role == 'storage' %\}|\{% elif alloy_node_role in \['app', 'storage'\] %\}" "$alloy_unit"
grep -Fq 'SupplementaryGroups=adm systemd-journal' "$alloy_unit"

grep -Fq 'local.file "garage_metrics_token"' "$alloy_config"
grep -Fq 'filename  = "/etc/alloy/secrets/garage-metrics-token"' "$alloy_config"
grep -Fq 'is_secret = true' "$alloy_config"
grep -Fq 'prometheus.scrape "garage"' "$alloy_config"
grep -Fq '"__address__" = "127.0.0.1:3903"' "$alloy_config"
grep -Fq 'metrics_path    = "/metrics"' "$alloy_config"
grep -Fq 'scrape_interval = "15s"' "$alloy_config"
grep -Fq 'type        = "Bearer"' "$alloy_config"
grep -Fq 'credentials = local.file.garage_metrics_token.content' "$alloy_config"
grep -Fq 'loki.source.journal "garage"' "$alloy_config"
grep -Fq 'matches    = "SYSLOG_IDENTIFIER=garage"' "$alloy_config"
grep -Fq 'forward_to = [loki.write.central.receiver]' "$alloy_config"
grep -Fq 'service     = "garage"' "$alloy_config"

if grep -R -Fq '/var/run/docker.sock' "$alloy_config" "$alloy_tasks" "$alloy_unit"; then
  echo 'Garage log collection must not grant Alloy Docker socket access.' >&2
  exit 1
fi

echo 'M7 Garage observability repository contract: PASS'
