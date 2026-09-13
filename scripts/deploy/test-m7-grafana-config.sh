#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
vars="$root/config/ansible/group_vars/all/main.yml"
site="$root/config/ansible/site.yml"
tasks="$root/config/ansible/roles/grafana/tasks/main.yml"
datasources="$root/monitoring/grafana/provisioning/datasources/datasources.yml"

grep -Fq 'grafana_image: grafana/grafana:13.2.1' "$vars"
grep -Fq 'grafana_memory_limit: 512m' "$vars"
grep -Fq 'grafana_cpu_limit: 0.5' "$vars"
grep -Fq "grafana_admin_password: \"{{ lookup('env', 'ARP_GRAFANA_ADMIN_PASSWORD') }}\"" "$vars"
grep -Eq 'roles: \[[^]]*grafana[^]]*\]' "$site"

grep -Fq 'image: "{{ grafana_image }}"' "$tasks"
grep -Fq 'GF_SERVER_HTTP_ADDR: "{{ observability_private_ip }}"' "$tasks"
grep -Fq 'GF_SECURITY_ADMIN_PASSWORD: "{{ grafana_admin_password }}"' "$tasks"
grep -Fq 'GF_AUTH_ANONYMOUS_ENABLED: "false"' "$tasks"
grep -Fq '/srv/observability/grafana:/var/lib/grafana' "$tasks"

grep -Fq 'uid: prometheus' "$datasources"
grep -Fq 'url: http://10.40.0.60:9090' "$datasources"
grep -Fq 'isDefault: true' "$datasources"
grep -Fq 'uid: loki' "$datasources"
grep -Fq 'url: http://10.40.0.60:3100' "$datasources"
grep -Fq 'uid: tempo' "$datasources"
grep -Fq 'url: http://127.0.0.1:3200' "$datasources"
test "$(grep -Fc 'editable: false' "$datasources")" -eq 3

if grep -Eq '0\.0\.0\.0|latest|admin/admin' "$tasks" "$datasources" "$vars"; then
  echo 'Grafana baseline must stay private, version-pinned, and free of default credentials.' >&2
  exit 1
fi

echo 'M7 Grafana repository contract: PASS'
