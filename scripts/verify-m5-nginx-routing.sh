#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist="$root/frontend/dist"
snippet="$root/config/ansible/roles/edge/files/arp-spa.conf"
tmp="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/arp-nginx-routing"
port="${ARP_NGINX_TEST_PORT:-18080}"

command -v nginx >/dev/null
command -v curl >/dev/null
test -f "$dist/index.html"
test -f "$snippet"

rm -rf "$tmp"
mkdir -p "$tmp"
cat > "$tmp/nginx.conf" <<EOF
pid $tmp/nginx.pid;
error_log $tmp/error.log notice;
events {}
http {
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  access_log $tmp/access.log;
  upstream arp_backend { server 127.0.0.1:8080; }
  server {
    listen 127.0.0.1:$port;
    server_name localhost;
    root $dist;
    index index.html;
    include $snippet;
  }
}
EOF

nginx -t -c "$tmp/nginx.conf"
nginx -c "$tmp/nginx.conf"
cleanup() {
  nginx -c "$tmp/nginx.conf" -s quit >/dev/null 2>&1 || true
}
trap cleanup EXIT

for attempt in $(seq 1 30); do
  if curl --fail --silent --output /dev/null "http://127.0.0.1:$port/"; then
    break
  fi
  if [ "$attempt" -eq 30 ]; then
    cat "$tmp/error.log" >&2 || true
    exit 1
  fi
  sleep 1
done

curl --fail --silent -D "$tmp/root.headers" -o "$tmp/root.html" "http://127.0.0.1:$port/"
cmp "$tmp/root.html" "$dist/index.html"
grep -Eiq '^Cache-Control: .*no-store' "$tmp/root.headers"

curl --fail --silent -o "$tmp/deep-route.html" "http://127.0.0.1:$port/applications/123/edit"
cmp "$tmp/deep-route.html" "$dist/index.html"

asset="$(find "$dist/assets" -maxdepth 1 -type f | head -n 1)"
test -n "$asset"
asset_name="$(basename "$asset")"
curl --fail --silent -D "$tmp/asset.headers" -o "$tmp/asset.body" "http://127.0.0.1:$port/assets/$asset_name"
grep -Eiq '^Cache-Control: .*max-age=31536000.*immutable' "$tmp/asset.headers"

curl --fail --silent -D "$tmp/api.headers" -o "$tmp/api.json" "http://127.0.0.1:$port/api/v1/programs"
grep -Eiq '^Content-Type: .*json' "$tmp/api.headers"
grep -Fq '"items"' "$tmp/api.json"

status="$(curl --silent --output "$tmp/api-404.body" --write-out '%{http_code}' "http://127.0.0.1:$port/api/v1/programs/999999999")"
test "$status" = "404"
! cmp -s "$tmp/api-404.body" "$dist/index.html"

grep -Fq 'location ^~ /api/' "$snippet"
grep -Fq 'try_files $uri $uri/ /index.html;' "$snippet"
grep -Fq 'client_max_body_size 12m;' "$snippet"
