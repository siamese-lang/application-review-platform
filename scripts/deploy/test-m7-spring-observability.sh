#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
pom="$root/app/pom.xml"
app_config="$root/app/src/main/resources/application.yml"
app_env="$root/config/ansible/roles/app/templates/arp.env.j2"
alloy="$root/monitoring/alloy/config.alloy"
app_logs="$root/monitoring/alloy/app-logs.alloy"
alloy_tasks="$root/config/ansible/roles/alloy/tasks/main.yml"
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

grep -Fq 'correlation: "[${spring.application.name:},traceId=%X{traceId:-},spanId=%X{spanId:-},requestId=%X{requestId:-}] "' "$app_config"
grep -Fq 'loki.source.journal "application"' "$app_logs"
grep -Fq 'matches    = "_SYSTEMD_UNIT=arp.service"' "$app_logs"
grep -Fq 'service     = "application-review-platform"' "$app_logs"
grep -Fq 'stream      = "application"' "$app_logs"
grep -Fq 'dest: /etc/alloy/app-logs.alloy' "$alloy_tasks"
grep -Fq "when: alloy_node_role == 'app'" "$alloy_tasks"
grep -Fq "{% elif alloy_node_role in ['app', 'storage'] %}" "$alloy_unit"
grep -Fq 'SupplementaryGroups=adm systemd-journal' "$alloy_unit"

if grep -Eq 'traceId.*target_label|spanId.*target_label|requestId.*target_label' "$app_logs"; then
  echo 'Correlation identifiers must stay in log content, not Loki labels.' >&2
  exit 1
fi

grep -Fq 'ARP_PROMETHEUS_REMOTE_WRITE_URL=http://{{ observability_private_ip }}:9090/api/v1/write' "$alloy_unit"
grep -Fq 'ARP_LOKI_PUSH_URL=http://{{ observability_private_ip }}:3100/loki/api/v1/push' "$alloy_unit"
grep -Fq 'ARP_TEMPO_OTLP_HTTP_ENDPOINT=http://{{ observability_private_ip }}:4318' "$alloy_unit"

if grep -Eq '0\.0\.0\.0:(9091|4318)' "$app_config" "$app_env" "$alloy" "$alloy_unit"; then
  echo 'Spring management and local OTLP receiver must remain loopback-only.' >&2
  exit 1
fi

echo 'M7 Spring observability repository contract: PASS'
