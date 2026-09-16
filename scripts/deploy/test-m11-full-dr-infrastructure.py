#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(path: str, *tokens: str) -> None:
    text = read(path)
    for token in tokens:
        if token not in text:
            raise SystemExit(f"{path}: missing required token: {token}")


variables = read("infra/opentofu/variables.tf")
start = variables.index('variable "enable_full_dr"')
full_dr_variables = variables[start:]
if "default     = false" not in full_dr_variables:
    raise SystemExit("M11 full DR infrastructure must remain opt-in by default")

require(
    "infra/opentofu/locals.tf",
    "dr-edge-01",
    "dr-app-01",
    "dr-db-01",
    "dr-storage-01",
    "dr-storage-02",
    "dr-storage-03",
    'role = "edge"',
    'role = "app"',
    'role = "db"',
    'role = "storage"',
)

require(
    "infra/opentofu/network.tf",
    'resource "google_compute_subnetwork" "full_dr"',
    'name                     = "arp-m11-dr-${var.full_dr_region}"',
    'ip_cidr_range            = var.full_dr_subnet_cidr',
    'resource "google_compute_router" "full_dr"',
    'resource "google_compute_router_nat" "full_dr"',
    'resource "google_compute_address" "full_dr_edge"',
)

require(
    "infra/opentofu/disks.tf",
    'resource "google_compute_disk" "full_dr_db"',
    'name  = "arp-dr-db-01-data"',
    'resource "google_compute_disk" "full_dr_storage"',
    'for_each = var.enable_full_dr ? local.full_dr_storage_nodes : {}',
    'type     = var.full_dr_data_disk_type',
)

compute = read("infra/opentofu/compute.tf")
compute_start = compute.index('resource "google_compute_instance" "full_dr"')
full_dr_compute = compute[compute_start:]
for token in [
    'for_each     = var.enable_full_dr ? local.full_dr_nodes : {}',
    'tags         = ["arp-dr-${each.value.role}", "arp-managed"]',
    'device_name = "arp-data"',
    'for_each = each.value.role == "edge" ? [1] : []',
    'nat_ip = google_compute_address.full_dr_edge[0].address',
    'condition     = var.enable_backup',
]:
    if token not in full_dr_compute:
        raise SystemExit(f"full DR compute contract missing: {token}")

if "service_account" in full_dr_compute:
    raise SystemExit("temporary full DR service VMs must not inherit a broad workload service account")

require(
    "infra/opentofu/firewall.tf",
    'resource "google_compute_firewall" "full_dr_edge_https"',
    'resource "google_compute_firewall" "full_dr_edge_app"',
    'resource "google_compute_firewall" "full_dr_app_db"',
    'resource "google_compute_firewall" "full_dr_app_garage"',
    'resource "google_compute_firewall" "full_dr_garage_rpc"',
    'resource "google_compute_firewall" "backup_full_dr_db_ssh"',
    'resource "google_compute_firewall" "full_dr_db_backup_ssh"',
    'resource "google_compute_firewall" "backup_full_dr_garage_s3"',
)

firewall = read("infra/opentofu/firewall.tf")
dr_start = firewall.index('resource "google_compute_firewall" "full_dr_edge_https"')
dr_firewall = firewall[dr_start:]
for token in [
    'source_tags = ["arp-dr-edge"]',
    'target_tags = ["arp-dr-app"]',
    'source_tags = ["arp-dr-app"]',
    'target_tags = ["arp-dr-db"]',
    'target_tags = ["arp-dr-storage"]',
    'source_tags = ["arp-dr-storage"]',
    'source_tags = ["arp-backup"]',
    'target_tags = ["arp-backup"]',
]:
    if token not in dr_firewall:
        raise SystemExit(f"full DR firewall contract missing: {token}")

for production_tag in [
    'target_tags = ["arp-app"]',
    'target_tags = ["arp-db"]',
    'target_tags = ["arp-storage"]',
]:
    if production_tag in dr_firewall:
        raise SystemExit(f"full DR service firewall must not target retained runtime tags: {production_tag}")

outputs = read("infra/opentofu/outputs.tf")
require(
    "infra/opentofu/outputs.tf",
    'output "full_dr_inventory"',
    'output "full_dr"',
    'edge_public_ip = google_compute_address.full_dr_edge[0].address',
)
inventory_start = outputs.index('output "inventory"')
inventory_end = outputs.index('output "loadgen"')
if "enable_full_dr" in outputs[inventory_start:inventory_end]:
    raise SystemExit("standard retained-runtime inventory must not silently include full DR nodes")

ssh_start = outputs.index('output "ssh_inventory"')
backup_start = outputs.index('output "backup"')
if "var.enable_full_dr" not in outputs[ssh_start:backup_start]:
    raise SystemExit("OS Login SSH inventory must include enabled full DR nodes")

print("M11 Phase 4 full DR infrastructure contract: PASS")
