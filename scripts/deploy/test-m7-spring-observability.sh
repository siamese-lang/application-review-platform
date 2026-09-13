#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
pom="$root/app/pom.xml"
app_config="$root/app/src/main/resources/application.yml"
app_env="$root/config/ansible/roles/app/templates/arp.env.j2"
alloy="$root/monitoring/alloy/config.alloy"
alloy_unit="$root/config/ansible/roles/alloy/templates/alloy.service.j2"
https_site="$root/config/ansible/roles/edge/templates/arp.conf.j2"
http_site="$root/config/ansible/roles/edge/templates/arp-http.conf.j2"
edge_role="$root/config/ansible/roles/edge"

grep -Fq '<artifactId>spring-boot-starter-actuator</artifactId>' "$pom"
grep -Fq '<artifactId>micrometer-registry-prometheus</artifactId>' "$pom"
grep -Fq '<artifactId>spring-boot-starter-opentelemetry</artifactId>' "$pom"

grep -Fq 'name: application-review-platform' "$app_config"
grep -Fq 'address: 127.0.0.1' "$app_config"
grep -Fq 'port: ${MANAGEMENT_SERVER_PORT:9091}' "$app_config"
grep -Fq 'include: health,prometheus' "$app_config"
grep -Fq 'probability: ${TRACING_SAMPLING_PROBABILITY:1.0}' "$app_config"
grep -Fq 'endpoint: ${OTEL_TRACES_ENDPOINT:http://127.0.0.1:4318/v1/traces}' "$app_config"

grep -Fq 'MANAGEMENT_SERVER_PORT=9091' "$app_env"
grep -Fq 'OTEL_TRACES_ENDPOINT=http://127.0.0.1:4318/v1/traces' "$app_env"
grep -Fq 'OTEL_SERVICE_NAME=application-review-platform' "$app_env"
grep -Fq 'deployment.environment.name=application-review-platform' "$app_env"
grep -Fq 'service.instance.id={{ inventory_hostname }}' "$app_env"

test "$(grep -Fc 'location ^~ /actuator { return 404; }' "$https_site")" -eq 2
test "$(grep -Fc 'location ^~ /actuator { return 404; }' "$http_site")" -eq 1
if grep -R -Eq 'proxy_pass[^;]*/actuator|location[^\n]*actuator[^\n]*proxy_pass' "$edge_role"; then
  echo 'Public Nginx must never proxy Actuator endpoints.' >&2
  exit 1
fi

grep -Fq 'discovery.relabel "spring_app"' "$alloy"
grep -Fq '"__address__" = "127.0.0.1:9091"' "$alloy"
grep -Fq 'source_labels = ["role"]' "$alloy"
grep -Fq 'regex         = "app"' "$alloy"
grep -Fq 'action        = "keep"' "$alloy"
grep -Fq 'prometheus.scrape "spring"' "$alloy"
grep -Fq 'metrics_path    = "/actuator/prometheus"' "$alloy"
grep -Fq 'otelcol.receiver.otlp "spring"' "$alloy"
grep -Fq 'endpoint = "127.0.0.1:4318"' "$alloy"
grep -Fq 'traces = [otelcol.processor.batch.traces.input]' "$alloy"
grep -Fq 'otelcol.exporter.otlphttp "tempo"' "$alloy"
grep -Fq 'endpoint = sys.env("ARP_TEMPO_OTLP_HTTP_ENDPOINT")' "$alloy"

grep -Fq 'ARP_TEMPO_OTLP_HTTP_ENDPOINT=http://' "$alloy_unit"
grep -Fq ':4318' "$alloy_unit"

if grep -Eq 'management:[[:space:]]*$' /dev/null; then
  :
fi
if grep -Eq '0\.0\.0\.0:(9091|4318)' "$app_config" "$app_env" "$alloy" "$alloy_unit"; then
  echo 'Spring management and local OTLP receiver must remain loopback-only.' >&2
  exit 1
fi

echo 'M7 Spring observability repository contract: PASS'
