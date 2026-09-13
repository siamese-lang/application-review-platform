#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
vars="$root/config/ansible/group_vars/all/main.yml"
site="$root/config/ansible/site.yml"
tasks="$root/config/ansible/roles/prometheus/tasks/main.yml"
unit="$root/config/ansible/roles/prometheus/templates/prometheus.service.j2"
config="$root/monitoring/prometheus/prometheus.yml"
rules="$root/monitoring/prometheus/rules/structural-alerts.yml"

grep -Fq 'prometheus_version: 3.13.3' "$vars"
grep -Fq 'prometheus_linux_amd64_sha256: b349c732d8a853e657d0e7ae1bbad4d11b586615fb65fdc59d896b9f869c001e' "$vars"
grep -Fq 'prometheus_retention_time: 3d' "$vars"
grep -Fq 'prometheus_retention_size: 12GB' "$vars"
grep -Fq 'observability_private_ip: 10.40.0.60' "$vars"

grep -Eq 'roles: \[[^]]*prometheus[^]]*\]' "$site"
grep -Fq '/dev/disk/by-id/google-arp-data' "$tasks"
grep -Fq 'checksum: "sha256:{{ prometheus_linux_amd64_sha256 }}"' "$tasks"

grep -Fq -- '--web.listen-address={{ observability_private_ip }}:9090' "$unit"
grep -Fq -- '--web.enable-remote-write-receiver' "$unit"
grep -Fq -- '--storage.tsdb.retention.time={{ prometheus_retention_time }}' "$unit"
grep -Fq -- '--storage.tsdb.retention.size={{ prometheus_retention_size }}' "$unit"

grep -Fq '10.40.0.60:9090' "$config"
grep -Fq '/etc/prometheus/rules/*.yml' "$config"
grep -Fq 'monitoring/prometheus/rules/structural-alerts.yml' "$tasks"
grep -Fq 'alert: ARPTargetUnavailable' "$rules"
grep -Fq 'alert: ARPApplicationHealthUnavailable' "$rules"
grep -Fq 'alert: ARPPostgreSQLUnavailable' "$rules"
grep -Fq 'alert: ARPFilesystemFreeSpaceCritical' "$rules"
test "$(grep -Fc 'severity: critical' "$rules")" -eq 3
test "$(grep -Fc 'severity: warning' "$rules")" -eq 1
if grep -Eq 'Garage|Alloy|latency|SLO' "$rules"; then
  echo 'Phase 2 structural rules must not invent unverified Garage/Alloy/SLO signals.' >&2
  exit 1
fi
if grep -Eq '0\.0\.0\.0:9090|latest' "$config" "$unit" "$tasks" "$vars"; then
  echo 'Prometheus baseline must stay private and version-pinned.' >&2
  exit 1
fi

echo 'M7 Prometheus repository contract: PASS'
