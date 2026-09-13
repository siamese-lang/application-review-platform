#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

grep -Fq 'edge-01    = { role = "edge", zone = "${var.region}-a", ip = "10.40.0.10" }' infra/opentofu/locals.tf
grep -Fq 'app-01     = { role = "app", zone = "${var.region}-a", ip = "10.40.0.20" }' infra/opentofu/locals.tf
grep -Fq 'db-01      = { role = "db", zone = "${var.region}-a", ip = "10.40.0.30" }' infra/opentofu/locals.tf
grep -Fq 'storage-01 = { role = "storage", zone = "${var.region}-a", ip = "10.40.0.41" }' infra/opentofu/locals.tf
grep -Fq 'storage-02 = { role = "storage", zone = "${var.region}-b", ip = "10.40.0.42" }' infra/opentofu/locals.tf
grep -Fq 'storage-03 = { role = "storage", zone = "${var.region}-c", ip = "10.40.0.43" }' infra/opentofu/locals.tf
grep -Fq 'ops-01     = { role = "ops", zone = "${var.region}-a", ip = "10.40.0.50" }' infra/opentofu/locals.tf
grep -Fq 'obs-01     = { role = "observability", zone = "${var.region}-a", ip = "10.40.0.60" }' infra/opentofu/locals.tf

grep -Fq 'observability = "e2-standard-2"' infra/opentofu/variables.tf
grep -Fq 'variable "observability_data_disk_size_gb"' infra/opentofu/variables.tf
grep -Fq 'labels       = { milestone = each.key == "obs-01" ? "m7" : "m4", role = each.value.role }' infra/opentofu/compute.tf
grep -Fq 'for_each = each.key == "edge-01" ? [1] : []' infra/opentofu/compute.tf
grep -Fq 'each.key == "obs-01" ? "pd-standard" : "pd-balanced"' infra/opentofu/compute.tf
grep -Fq 'each.key == "obs-01" ? [google_compute_disk.observability.id]' infra/opentofu/compute.tf

grep -Fq 'resource "google_compute_disk" "observability"' infra/opentofu/disks.tf
grep -Fq 'name = "arp-obs-01-data"' infra/opentofu/disks.tf
grep -Fq 'type = "pd-standard"' infra/opentofu/disks.tf
grep -Fq 'size = var.observability_data_disk_size_gb' infra/opentofu/disks.tf

grep -Fq 'resource "google_compute_firewall" "telemetry_observability"' infra/opentofu/firewall.tf
grep -Fq 'source_tags = ["arp-edge", "arp-app", "arp-db", "arp-storage"]' infra/opentofu/firewall.tf
grep -Fq 'target_tags = ["arp-observability"]' infra/opentofu/firewall.tf
grep -Fq 'ports    = ["9090", "3100", "4317", "4318"]' infra/opentofu/firewall.tf
grep -Fq 'resource "google_compute_firewall" "ops_grafana"' infra/opentofu/firewall.tf
grep -Fq 'source_tags = ["arp-ops"]' infra/opentofu/firewall.tf
grep -Fq 'ports    = ["3000"]' infra/opentofu/firewall.tf

grep -Fq 'observability: { hosts: { obs-01: { ansible_host: 10.40.0.60 } } }' config/ansible/inventory/example.yml
for component in alloy prometheus loki tempo grafana alertmanager; do
  test -d "monitoring/$component"
done

inventory_output=$(printf '%s' '{"edge-01":{"role":"edge","zone":"asia-northeast3-a","private_ip":"10.40.0.10"},"obs-01":{"role":"observability","zone":"asia-northeast3-a","private_ip":"10.40.0.60"}}' | python3 deploy/generate-inventory.py)
grep -Fq 'observability:' <<<"$inventory_output"
grep -Fq 'obs-01:' <<<"$inventory_output"
grep -Fq 'ansible_host: 10.40.0.60' <<<"$inventory_output"

if awk '/resource "google_compute_firewall" "ops_grafana"/{flag=1} flag{print} flag && /^}/{exit}' infra/opentofu/firewall.tf | grep -Fq 'source_ranges'; then
  echo 'Grafana must not have source_ranges/public ingress.' >&2
  exit 1
fi

if awk '/resource "google_compute_firewall" "telemetry_observability"/{flag=1} flag{print} flag && /^}/{exit}' infra/opentofu/firewall.tf | grep -Fq 'source_ranges'; then
  echo 'Telemetry ingress must remain tag-restricted, not source-range public.' >&2
  exit 1
fi

echo 'M7 Phase 1 observability infrastructure contract: PASS'
