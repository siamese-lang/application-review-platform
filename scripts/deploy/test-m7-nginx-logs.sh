#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
log_format="$root/config/ansible/roles/edge/templates/arp-observability.conf.j2"
https_site="$root/config/ansible/roles/edge/templates/arp.conf.j2"
http_site="$root/config/ansible/roles/edge/templates/arp-http.conf.j2"
spa="$root/config/ansible/roles/edge/files/arp-spa.conf"
edge_tasks="$root/config/ansible/roles/edge/tasks/main.yml"
alloy="$root/monitoring/alloy/config.alloy"
alloy_unit="$root/config/ansible/roles/alloy/templates/alloy.service.j2"

grep -Fq 'log_format arp_json escape=json' "$log_format"
grep -Fq '"request_id":"$request_id"' "$log_format"
grep -Fq '"method":"$request_method"' "$log_format"
grep -Fq '"path":"$uri"' "$log_format"
grep -Fq '"status":$status' "$log_format"
grep -Fq '"request_time":$request_time' "$log_format"
grep -Fq '"upstream_time":"$upstream_response_time"' "$log_format"

if grep -Eq '\$(args|request_uri|http_cookie|http_authorization|request_body)([^A-Za-z0-9_]|$)' "$log_format"; then
  echo 'Nginx observability access logs must not contain query strings, cookies, authorization headers, or request bodies.' >&2
  exit 1
fi

test "$(grep -Fc 'access_log /var/log/nginx/arp-access.log arp_json;' "$https_site")" -eq 2
test "$(grep -Fc 'error_log /var/log/nginx/arp-error.log warn;' "$https_site")" -eq 2
grep -Fq 'access_log /var/log/nginx/arp-access.log arp_json;' "$http_site"
grep -Fq 'error_log /var/log/nginx/arp-error.log warn;' "$http_site"

test "$(grep -Fc 'proxy_set_header X-Request-ID $request_id;' "$spa")" -eq 2
test "$(grep -Fc 'add_header X-Request-ID $request_id always;' "$spa")" -eq 2

grep -Fq 'src: arp-observability.conf.j2' "$edge_tasks"
grep -Fq 'dest: /etc/nginx/conf.d/arp-observability.conf' "$edge_tasks"
grep -Fq '/var/log/nginx/arp-access.log' "$edge_tasks"
grep -Fq '/var/log/nginx/arp-error.log' "$edge_tasks"
grep -Fq 'group: adm' "$edge_tasks"
grep -Fq "mode: '0640'" "$edge_tasks"

grep -Fq 'loki.source.file "nginx"' "$alloy"
grep -Fq '"__path__"    = "/var/log/nginx/arp-access.log"' "$alloy"
grep -Fq '"__path__"    = "/var/log/nginx/arp-error.log"' "$alloy"
grep -Fq '"stream"      = "access"' "$alloy"
grep -Fq '"stream"      = "error"' "$alloy"
grep -Fq 'forward_to = [loki.write.central.receiver]' "$alloy"
grep -Fq 'file_match {' "$alloy"
grep -Fq 'loki.write "central"' "$alloy"
grep -Fq 'url = sys.env("ARP_LOKI_PUSH_URL")' "$alloy"

grep -Fq "if alloy_node_role == 'edge'" "$alloy_unit"
grep -Fq 'SupplementaryGroups=adm' "$alloy_unit"
grep -Fq 'ARP_LOKI_PUSH_URL=http://' "$alloy_unit"
grep -Fq ':3100/loki/api/v1/push' "$alloy_unit"

if grep -Eq '0\.0\.0\.0:3100|latest' "$alloy" "$alloy_unit"; then
  echo 'Nginx log shipping must remain private and version-pinned.' >&2
  exit 1
fi

echo 'M7 Nginx-to-Loki repository contract: PASS'
