#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root"

template=config/ansible/roles/garage_proxy/templates/garage-s3-proxy.conf.j2
tasks=config/ansible/roles/garage_proxy/tasks/main.yml
site=config/ansible/site.yml
env_template=config/ansible/roles/app/templates/arp.env.j2
firewall=infra/opentofu/firewall.tf
compute=infra/opentofu/compute.tf
adr=docs/architecture/ADR-005-garage-endpoint-failover.md

for path in "$template" "$tasks" "$site" "$env_template" "$firewall" "$compute" "$adr"; do
  test -f "$path"
done

grep -Fq "listen 127.0.0.1:{{ garage_proxy_port }};" "$template"
grep -Fq "groups['storage']" "$template"
grep -Fq 'proxy_set_header Host $http_host;' "$template"
grep -Fq 'proxy_next_upstream error timeout http_502 http_503 http_504;' "$template"
grep -Fq 'proxy_next_upstream_tries 3;' "$template"
grep -Fq 'proxy_max_temp_file_size 0;' "$template"
grep -Fq 'client_max_body_size 12m;' "$template"

grep -Fq 'name: nginx' "$tasks"
grep -Fq 'ansible.builtin.meta: flush_handlers' "$tasks"

python3 - "$site" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
needle = "roles: [release_runtime, garage_proxy, app, alloy]"
if needle not in text:
    raise SystemExit("app play must activate garage_proxy before app")
PY

grep -Fq 'GARAGE_ENDPOINT=http://127.0.0.1:{{ garage_proxy_port }}' "$env_template"
if grep -Fq 'GARAGE_ENDPOINT=http://{{ garage_endpoint_ip }}' "$env_template"; then
  echo "application must not retain the fixed storage-01 Garage endpoint" >&2
  exit 1
fi

python3 - "$firewall" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
start = text.index('resource "google_compute_firewall" "app_garage"')
end = text.index('\n}', start) + 2
block = text[start:end]
if 'target_tags = ["arp-storage"]' not in block:
    raise SystemExit("app_garage firewall must target all storage nodes")
if "arp-garage-endpoint" in block:
    raise SystemExit("app_garage firewall must not retain fixed endpoint tag")
PY

if grep -Fq 'arp-garage-endpoint' "$compute"; then
  echo "compute instances must not retain obsolete fixed Garage endpoint tag" >&2
  exit 1
fi

grep -Fq 'Status: ACCEPTED' "$adr"
grep -Fq '127.0.0.1:3910' "$adr"
grep -Fq 'storage-01:3900' "$adr"
grep -Fq 'storage-02:3900' "$adr"
grep -Fq 'storage-03:3900' "$adr"

echo "M10 Garage endpoint failover repository contract: PASS"
