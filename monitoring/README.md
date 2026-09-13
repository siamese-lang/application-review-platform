# M7 Monitoring Configuration

This directory is the repository-owned configuration boundary for M7 Observability.

Phase 1 creates the structure only. Central-stack and node-collector configuration are
implemented in later M7 phases after the private `obs-01` infrastructure boundary is
reviewed and merged.

Planned component directories:

- `alloy/` — node-local metrics/logs/traces collection and forwarding;
- `prometheus/` — metrics storage, recording/alert rules, and scrape/remote-write contract;
- `loki/` — centralized logs;
- `tempo/` — distributed traces;
- `grafana/` — datasource/dashboard provisioning;
- `alertmanager/` — internal alert routing.

Guardrails:

- no credentials or decrypted SOPS material;
- no public listener assumptions;
- no floating `latest` image tags in final runtime configuration;
- dashboards/rules are provisioned from Git rather than being durable only in Grafana UI;
- M8/M9 performance conclusions do not belong here before representative workload evidence.
