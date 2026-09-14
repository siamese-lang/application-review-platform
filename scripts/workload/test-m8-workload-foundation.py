#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, token: str, context: str) -> None:
    if token not in text:
        raise SystemExit(f"missing {context}: {token}")


locals_tf = read("infra/opentofu/locals.tf")
variables_tf = read("infra/opentofu/variables.tf")
network_tf = read("infra/opentofu/network.tf")
compute_tf = read("infra/opentofu/compute.tf")
outputs_tf = read("infra/opentofu/outputs.tf")
tfvars_example = read("infra/opentofu/terraform.tfvars.example")
ci = read(".github/workflows/baseline-ci.yml")
oslogin_helper = read("deploy/with-oslogin-ssh.py")

expected_nodes = [
    'edge-01    = { role = "edge", zone = "${var.region}-a", ip = "10.40.0.10" }',
    'app-01     = { role = "app", zone = "${var.region}-a", ip = "10.40.0.20" }',
    'db-01      = { role = "db", zone = "${var.region}-a", ip = "10.40.0.30" }',
    'storage-01 = { role = "storage", zone = "${var.region}-a", ip = "10.40.0.41" }',
    'storage-02 = { role = "storage", zone = "${var.region}-b", ip = "10.40.0.42" }',
    'storage-03 = { role = "storage", zone = "${var.region}-c", ip = "10.40.0.43" }',
    'ops-01     = { role = "ops", zone = "${var.region}-a", ip = "10.40.0.50" }',
    'obs-01     = { role = "observability", zone = "${var.region}-a", ip = "10.40.0.60" }',
]
for node in expected_nodes:
    require(locals_tf, node, "persistent Seoul node")

if "loadgen-01" in locals_tf:
    raise SystemExit("temporary loadgen-01 must not be added to persistent local.nodes")

for token in [
    'variable "enable_loadgen"',
    'default     = false',
    'variable "loadgen_region"',
    'default     = "asia-northeast1"',
    'variable "loadgen_zone"',
    'default     = "asia-northeast1-a"',
    'variable "loadgen_machine_type"',
    'default     = "e2-standard-2"',
]:
    require(variables_tf, token, "loadgen variable contract")

for token in [
    'resource "google_compute_subnetwork" "loadgen"',
    'resource "google_compute_router" "loadgen"',
    'resource "google_compute_router_nat" "loadgen"',
    'count                    = var.enable_loadgen ? 1 : 0',
    'region                   = var.loadgen_region',
]:
    require(network_tf, token, "cross-region loadgen network contract")

start = compute_tf.find('resource "google_compute_instance" "loadgen"')
if start < 0:
    raise SystemExit("missing loadgen instance resource")
loadgen_block = compute_tf[start:]

for token in [
    'count        = var.enable_loadgen ? 1 : 0',
    'name         = "loadgen-01"',
    'zone         = var.loadgen_zone',
    'machine_type = var.loadgen_machine_type',
    'tags         = ["arp-loadgen", "arp-managed"]',
    'type  = "pd-standard"',
    'subnetwork = google_compute_subnetwork.loadgen[0].id',
    'network_ip = var.loadgen_private_ip',
]:
    require(loadgen_block, token, "loadgen instance contract")

if "access_config" in loadgen_block:
    raise SystemExit("loadgen-01 must not have a public access_config")
if "service_account" in loadgen_block:
    raise SystemExit("loadgen-01 must not inherit a broad workload service account")

require(
    compute_tf,
    'for_each = each.key == "edge-01" ? [1] : []',
    "existing edge-only public access contract",
)
require(outputs_tf, 'output "loadgen"', "loadgen output")
require(outputs_tf, "var.enable_loadgen ?", "conditional loadgen output")
require(outputs_tf, 'output "ssh_inventory"', "SSH inventory output")
require(outputs_tf, '"loadgen-01" = {', "conditional SSH loadgen inventory")
require(outputs_tf, 'role       = "loadgen"', "SSH loadgen role")

for token in [
    '# enable_loadgen        = true',
    '# loadgen_region        = "asia-northeast1"',
    '# loadgen_zone          = "asia-northeast1-a"',
]:
    require(tfvars_example, token, "documented opt-in loadgen example")

tool_versions = {}
for line in read("workload/tool-versions.env").splitlines():
    if not line.strip():
        continue
    key, value = line.split("=", 1)
    tool_versions[key] = value

if tool_versions.get("K6_VERSION") != "2.2.0":
    raise SystemExit("k6 must remain pinned to 2.2.0 for this Phase 1 baseline")
if tool_versions.get("K6_LINUX_AMD64_DEB_SHA256") != (
    "58b6468440332f882dba76efa87fb3b6d6eea0e3bd96090e3a5d5159f35832e0"
):
    raise SystemExit("k6 linux-amd64 deb checksum does not match the pinned Phase 1 artifact")

smoke = read("workload/k6/foundation-smoke.js")
for token in [
    "__ENV.BASE_URL",
    "foundation-public-programs",
    "endpoint_family",
    "GET /api/v1/programs",
]:
    require(smoke, token, "foundation k6 contract")

for forbidden in ["application_id", "request_id", "user_id", "username"]:
    if forbidden in smoke.lower():
        raise SystemExit(f"high-cardinality identifier must not appear in k6 tags: {forbidden}")

manifest = json.loads(read("workload/run-manifest.example.json"))
schema = json.loads(read("workload/run-manifest.schema.json"))

required_top = {
    "schema_version",
    "run_id",
    "source_sha",
    "release_sha",
    "dataset",
    "loadgen",
    "workload",
    "runtime",
    "started_at",
    "finished_at",
}
if set(schema.get("required", [])) != required_top:
    raise SystemExit("run manifest schema required fields drifted")
if not required_top.issubset(manifest):
    raise SystemExit("run manifest example is missing required fields")

expected_runtime_nodes = {
    "edge-01",
    "app-01",
    "db-01",
    "storage-01",
    "storage-02",
    "storage-03",
    "ops-01",
    "obs-01",
}
if set(manifest["runtime"]["persistent_nodes"]) != expected_runtime_nodes:
    raise SystemExit("manifest must identify exactly the retained eight-node runtime")
if manifest["loadgen"]["region"] != "asia-northeast1":
    raise SystemExit("manifest example must keep Tokyo as the default loadgen region")

secret_assignment = re.compile(
    r"(?i)(password|secret|token|cookie|csrf)\s*[:=]\s*['\"][^'\"]+['\"]"
)
for path in (ROOT / "workload").rglob("*"):
    if path.is_file():
        text = path.read_text(encoding="utf-8")
        if secret_assignment.search(text):
            raise SystemExit(f"literal secret-like assignment found in {path.relative_to(ROOT)}")

for token in [
    '"ssh_inventory"',
    "runtime_ssh_inventory(repo_root)",
]:
    require(oslogin_helper, token, "OS Login SSH inventory contract")

if '"inventory"' in oslogin_helper.split("def runtime_ssh_inventory", 1)[1].split("def register_ephemeral_key", 1)[0]:
    raise SystemExit("OS Login helper must use ssh_inventory, not persistent deployment inventory")

for token in [
    "m8-workload-foundation-static:",
    "python3 scripts/workload/test-m8-workload-foundation.py",
    "node --check workload/k6/foundation-smoke.js",
]:
    require(ci, token, "M8 CI contract")

print("M8 Phase 1 workload foundation contract: PASS")
