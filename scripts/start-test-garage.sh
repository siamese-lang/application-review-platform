#!/usr/bin/env bash
set -euo pipefail

image=dxflrs/garage:v2.4.1
docker rm -f arp-test-garage >/dev/null 2>&1 || true
docker run -d --name arp-test-garage --rm -p 3900:3900 \
  -e GARAGE_DEFAULT_ACCESS_KEY="$GARAGE_ACCESS_KEY" \
  -e GARAGE_DEFAULT_SECRET_KEY="$GARAGE_SECRET_KEY" \
  -e GARAGE_DEFAULT_BUCKET="$GARAGE_BUCKET" \
  "$image" server --single-node --default-bucket >/dev/null

for attempt in $(seq 1 60); do
  if curl --silent --output /dev/null --connect-timeout 1 http://127.0.0.1:3900/; then
    exit 0
  fi
  sleep 1
done
docker logs arp-test-garage
exit 1
