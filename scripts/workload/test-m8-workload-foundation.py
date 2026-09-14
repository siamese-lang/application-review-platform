#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
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
loadgen_preflight = read("deploy/m8-loadgen-preflight.sh")

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

w1 = read("workload/k6/w1-smoke.js")
w1_runner = read("workload/run-w1.sh")
for token in [
    "executor: 'per-vu-iterations'",
    "vus: 1",
    "iterations: 1",
    "maxDuration: '2m'",
    "checks: ['rate==1']",
    "http_req_failed: ['rate==0']",
    "systemTags:",
    "endpoint_family",
    "'list-detail'",
    "'create-save'",
    "'submit-resubmit'",
    "'reviewer-queue-detail'",
    "'review-action'",
    "'attachment'",
    "/api/v1/auth/csrf",
    "/api/v1/auth/login",
    "/api/v1/programs/8000000001",
    "/api/v1/applications",
    "/api/v1/review/applications",
    "http.file(",
    "../fixtures/w1-attachment.txt",
    "attachment cleanup succeeds",
    "request-revision",
    "/approve",
]:
    require(w1, token, "W1 k6 correctness contract")

system_tags = w1.split("systemTags:", 1)[1].split("],", 1)[0]
if "'url'" in system_tags or '"url"' in system_tags:
    raise SystemExit("W1 must exclude the dynamic URL system tag to avoid id cardinality")

for token in [
    "ARP_EXPECTED_SOURCE_SHA",
    "SYNTHETIC_APPLICANT_PASSWORD",
    "SYNTHETIC_REVIEWER_PASSWORD",
    "ARP_M8_DATASET_PROFILE=S",
    "ARP_CONFIRM_M8_DATASET_RESET",
    "with-oslogin-ssh.py",
    "--ttl-seconds 1800",
    "output -json loadgen",
    "output -raw edge_public_ip",
    "/opt/arp/release-state/backend.json",
    "/opt/arp/release-state/frontend.json",
    "component_releases",
    '"$backend_release_sha"   "$frontend_release_sha"',
    "W1_BACKEND_RELEASE_SHA",
    "W1_FRONTEND_RELEASE_SHA",
    "StrictHostKeyChecking=yes",
    "IFS= read -r APPLICANT_PASSWORD",
    "IFS= read -r REVIEWER_PASSWORD",
    "--summary-export summary.json",
    "run-manifest.json",
    '"name": "S"',
    '"scenario": "w1-business-smoke"',
    '"vus": 1',
    "PASS: M8 W1 exercised list/detail",
]:
    require(w1_runner, token, "W1 runner contract")

for forbidden in [
    "StrictHostKeyChecking=no",
    "tofu apply",
    "gcloud compute instances create",
    "-e APPLICANT_PASSWORD=",
    "-e REVIEWER_PASSWORD=",
]:
    if forbidden in w1_runner:
        raise SystemExit(f"W1 runner must not contain: {forbidden}")

subprocess.run(
    ["node", "--check", str(ROOT / "workload/k6/w1-smoke.js")],
    check=True,
)
subprocess.run(
    ["bash", "-n", str(ROOT / "workload/run-w1.sh")],
    check=True,
)

w2 = read("workload/k6/w2-baseline.js")
w2_runner = read("workload/run-w2.sh")
w2_overlay = read("workload/sql/w2-interactive-overlay.sql")

for token in [
    "executor: 'constant-vus'",
    "duration: '15m'",
    "exec: 'listDetail'",
    "vus: 12",
    "exec: 'createSave'",
    "vus: 4",
    "exec: 'submitResubmit'",
    "vus: 3",
    "exec: 'reviewerQueueDetail'",
    "vus: 6",
    "exec: 'reviewAction'",
    "exec: 'attachment'",
    "vus: 2",
    "m8_non_file_errors",
    "m8_non_file_duration",
    "new Counter(`m8_${family}_requests`)",
    "new Rate(`m8_${family}_errors`)",
    "new Trend(`m8_${family}_duration`, true)",
    "pace(started, 2.0)",
    "pace(started, 1.777778)",
    "pace(started, 1.0)",
    "pace(started, 2.666667)",
    "slot >= 4000",
    "slot >= 3500",
    "4000 + (exec.scenario.iterationInTest % 2500)",
    "7800 + (exec.vu.idInTest % 100)",
    "request-revision",
    "/reject",
    "/approve",
]:
    require(w2, token, "W2 k6 baseline contract")

w2_vus = [int(value) for value in re.findall(r"\bvus:\s*(\d+)", w2)]
if sorted(w2_vus) != [2, 3, 3, 4, 6, 12] or sum(w2_vus) != 30:
    raise SystemExit(f"W2 must retain exact 30-VU scenario allocation: {w2_vus!r}")
if w2.count("duration: '15m'") != 6:
    raise SystemExit("every W2 scenario must retain the 15-minute baseline duration")

w2_system_tags = w2.split("systemTags:", 1)[1].split("],", 1)[0]
if "'url'" in w2_system_tags or '"url"' in w2_system_tags:
    raise SystemExit("W2 must exclude the dynamic URL system tag to avoid id cardinality")

for token in [
    'ARP_M8_DATASET_PROFILE=M',
    "ARP_M8_W2_DATASET_READY",
    "w2-interactive-overlay.sql",
    "pg_stat_statements_reset()",
    "pg-stat-statements-top20.csv",
    "r.rolname = 'arp_app'",
    '"name": "M"',
    '"overlay_version": f"sha256:{overlay_sha}"',
    '"scenario": "w2-mixed-normal-baseline"',
    '"vus": 30',
    '"duration": "15m"',
    '"pacing_model":',
    "W2_NON_FILE_SUCCESS_RATE",
    "W2_NON_FILE_P95_MS",
    "W2_REGRESSION_TARGET",
    "W2_OVERLAY_SHA256",
    "PASS: M8 W2 completed and retained",
]:
    require(w2_runner, token, "W2 runner contract")

for token in [
    "m6-applicant",
    "role = 'APPLICANT'",
    "draft_count <> 8334",
    "history_count <> 0",
    "UPDATE applications a",
    "SET applicant_id = applicant.id",
    "UPDATE audit_events e",
    "SET actor_id = applicant.id",
    "owned_drafts <> 8334",
    "wrong_create_actor <> 0",
]:
    require(w2_overlay, token, "W2 deterministic interactive overlay")

for forbidden in [
    "StrictHostKeyChecking=no",
    "tofu apply",
    "gcloud compute instances create",
    "-e APPLICANT_PASSWORD=",
    "-e REVIEWER_PASSWORD=",
]:
    if forbidden in w2_runner:
        raise SystemExit(f"W2 runner must not contain: {forbidden}")

if re.search(r'\$\{ssh_db\[@\]\}.*\s-c\s', w2_runner):
    raise SystemExit("W2 remote psql must send SQL over stdin instead of ssh -c arguments")

subprocess.run(
    ["node", "--check", str(ROOT / "workload/k6/w2-baseline.js")],
    check=True,
)
subprocess.run(
    ["bash", "-n", str(ROOT / "workload/run-w2.sh")],
    check=True,
)

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
    "readonly LOADGEN_REGION=asia-northeast1",
    "readonly LOADGEN_ZONE=asia-northeast1-a",
    "readonly LOADGEN_MACHINE_TYPE=e2-standard-2",
    "readonly LOADGEN_NAME=loadgen-01",
    "gcloud compute machine-types describe",
    "gcloud compute regions describe",
    "gcloud compute instances list",
    "Persistent Seoul runtime: all 8 expected nodes present.",
    "Temporary loadgen-01: absent",
    "PASS: M8 Phase 3 read-only loadgen preflight completed.",
]:
    require(loadgen_preflight, token, "M8 live preflight contract")

for forbidden in [" create ", " delete ", " update ", " set-machine-type ", " add-access-config "]:
    if forbidden in loadgen_preflight:
        raise SystemExit(f"M8 loadgen preflight must remain read-only: {forbidden.strip()}")

for token in [
    "m8-workload-foundation-static:",
    "python3 scripts/workload/test-m8-workload-foundation.py",
    "node --check workload/k6/foundation-smoke.js",
]:
    require(ci, token, "M8 CI contract")

print("M8 Phase 1 workload foundation contract: PASS")
