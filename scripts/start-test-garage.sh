#!/usr/bin/env bash
set -euo pipefail

image=dxflrs/garage:v2.4.1
fixture_dir="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/arp-test-garage"
rm -rf "$fixture_dir"
mkdir -p "$fixture_dir/meta" "$fixture_dir/data"
cat >"$fixture_dir/garage.toml" <<'EOF'
metadata_dir = "/var/lib/garage/meta"
data_dir = "/var/lib/garage/data"
db_engine = "sqlite"
replication_factor = 1

rpc_bind_addr = "[::]:3901"
rpc_public_addr = "127.0.0.1:3901"
rpc_secret = "1111111111111111111111111111111111111111111111111111111111111111"

[s3_api]
s3_region = "garage"
api_bind_addr = "[::]:3900"
EOF

docker rm -f arp-test-garage >/dev/null 2>&1 || true
docker run -d --name arp-test-garage --rm -p 3900:3900 \
  -v "$fixture_dir/garage.toml:/etc/garage.toml:ro" \
  -v "$fixture_dir/meta:/var/lib/garage/meta" \
  -v "$fixture_dir/data:/var/lib/garage/data" \
  -e GARAGE_DEFAULT_ACCESS_KEY="$GARAGE_ACCESS_KEY" \
  -e GARAGE_DEFAULT_SECRET_KEY="$GARAGE_SECRET_KEY" \
  -e GARAGE_DEFAULT_BUCKET="$GARAGE_BUCKET" \
  "$image" /garage server --single-node --default-bucket >/dev/null

for attempt in $(seq 1 60); do
  if curl --silent --output /dev/null --connect-timeout 1 http://127.0.0.1:3900/; then
    exit 0
  fi
  sleep 1
done
docker logs arp-test-garage
exit 1
