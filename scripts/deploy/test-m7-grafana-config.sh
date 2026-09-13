#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
vars="$root/config/ansible/group_vars/all/main.yml"
site="$root/config/ansible/site.yml"
tasks="$root/config/ansible/roles/grafana/tasks/main.yml"
datasources="$root/monitoring/grafana/provisioning/datasources/datasources.yml"
dashboard_provider="$root/monitoring/grafana/provisioning/dashboards/dashboards.yml"
dashboard_dir="$root/monitoring/grafana/dashboards"

grep -Fq 'grafana_image: grafana/grafana:13.2.1' "$vars"
grep -Fq 'grafana_memory_limit: 512m' "$vars"
grep -Fq 'grafana_cpu_limit: 0.5' "$vars"
grep -Fq "grafana_admin_password: \"{{ lookup('env', 'ARP_GRAFANA_ADMIN_PASSWORD') }}\"" "$vars"
grep -Eq 'roles: \[[^]]*grafana[^]]*\]' "$site"

grep -Fq 'image: "{{ grafana_image }}"' "$tasks"
grep -Fq 'GF_SERVER_HTTP_ADDR: "{{ observability_private_ip }}"' "$tasks"
grep -Fq 'GF_SECURITY_ADMIN_PASSWORD: "{{ grafana_admin_password }}"' "$tasks"
grep -Fq 'GF_AUTH_ANONYMOUS_ENABLED: "false"' "$tasks"
grep -Fq '/etc/grafana/dashboards:/etc/grafana/dashboards:ro' "$tasks"
grep -Fq '/srv/observability/grafana:/var/lib/grafana' "$tasks"

grep -Fq 'uid: prometheus' "$datasources"
grep -Fq 'url: http://10.40.0.60:9090' "$datasources"
grep -Fq 'isDefault: true' "$datasources"
grep -Fq 'uid: loki' "$datasources"
grep -Fq 'url: http://10.40.0.60:3100' "$datasources"
grep -Fq 'uid: tempo' "$datasources"
grep -Fq 'url: http://127.0.0.1:3200' "$datasources"
test "$(grep -Fc 'editable: false' "$datasources")" -eq 3

grep -Fq 'name: arp-observability' "$dashboard_provider"
grep -Fq 'folder: Application Review Platform' "$dashboard_provider"
grep -Fq 'allowUiUpdates: false' "$dashboard_provider"
grep -Fq 'path: /etc/grafana/dashboards' "$dashboard_provider"

for dashboard in \
  system-overview.json \
  application-api.json \
  postgresql.json \
  garage.json; do
  test -s "$dashboard_dir/$dashboard"
  jq -e '.uid and .title and (.editable == false) and (.panels | length > 0)' "$dashboard_dir/$dashboard" >/dev/null
done

grep -Fq '"uid": "arp-system-overview"' "$dashboard_dir/system-overview.json"
grep -Fq '"uid": "arp-application-api"' "$dashboard_dir/application-api.json"
grep -Fq '"uid": "arp-postgresql"' "$dashboard_dir/postgresql.json"
grep -Fq '"uid": "arp-garage"' "$dashboard_dir/garage.json"

if grep -Eq '0\.0\.0\.0|latest|admin/admin' "$tasks" "$datasources" "$vars"; then
  echo 'Grafana baseline must stay private, version-pinned, and free of default credentials.' >&2
  exit 1
fi

echo 'M7 Grafana repository contract: PASS'
