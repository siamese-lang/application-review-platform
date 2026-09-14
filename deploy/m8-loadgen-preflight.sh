#!/usr/bin/env bash
set -euo pipefail

# Read-only M8 Phase 3 preflight. This script performs no GCP mutation.
readonly PROJECT_ID=application-review-platform
readonly LOADGEN_REGION=asia-northeast1
readonly LOADGEN_ZONE=asia-northeast1-a
readonly LOADGEN_MACHINE_TYPE=e2-standard-2
readonly LOADGEN_NAME=loadgen-01
readonly PERSISTENT_NODES=(
  edge-01
  app-01
  db-01
  storage-01
  storage-02
  storage-03
  ops-01
  obs-01
)

for command in gcloud python3; do
  command -v "$command" >/dev/null || {
    echo "Missing prerequisite: $command" >&2
    exit 1
  }
done

active_count=$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | sed '/^$/d' | wc -l)
(( active_count > 0 )) || {
  echo 'No active gcloud identity is available.' >&2
  exit 1
}
echo 'Active gcloud identity: present (identity and credentials not printed).'

gcloud projects describe "$PROJECT_ID" --format='none'
echo "Target project is accessible: $PROJECT_ID"

gcloud compute machine-types describe "$LOADGEN_MACHINE_TYPE"   --zone="$LOADGEN_ZONE"   --project="$PROJECT_ID"   --format='none'
echo "Load-generator machine type is inspectable in $LOADGEN_ZONE: $LOADGEN_MACHINE_TYPE"

project_quota=$(mktemp)
regional_quota=$(mktemp)
instances_json=$(mktemp)
trap 'rm -f "$project_quota" "$regional_quota" "$instances_json"' EXIT

gcloud compute project-info describe   --project="$PROJECT_ID"   --format=json >"$project_quota"

gcloud compute regions describe "$LOADGEN_REGION"   --project="$PROJECT_ID"   --format=json >"$regional_quota"

gcloud compute instances list   --project="$PROJECT_ID"   --format=json >"$instances_json"

echo 'Relevant project Compute quotas (metric, limit, usage):'
python3 - "$project_quota" <<'PY'
import json
import sys

wanted = {
    "CPUS",
    "CPUS_ALL_REGIONS",
    "INSTANCES",
    "IN_USE_ADDRESSES",
    "DISKS_TOTAL_GB",
    "SSD_TOTAL_GB",
}
for quota in json.load(open(sys.argv[1], encoding="utf-8")).get("quotas", []):
    if quota.get("metric") in wanted:
        print(
            f"  {quota['metric']}: "
            f"limit={quota.get('limit')} usage={quota.get('usage')}"
        )
PY

echo "Relevant $LOADGEN_REGION Compute quotas (metric, limit, usage):"
python3 - "$regional_quota" <<'PY'
import json
import sys

wanted = {
    "CPUS",
    "CPUS_ALL_REGIONS",
    "INSTANCES",
    "IN_USE_ADDRESSES",
    "DISKS_TOTAL_GB",
    "SSD_TOTAL_GB",
}
for quota in json.load(open(sys.argv[1], encoding="utf-8")).get("quotas", []):
    if quota.get("metric") in wanted:
        print(
            f"  {quota['metric']}: "
            f"limit={quota.get('limit')} usage={quota.get('usage')}"
        )
PY

python3 - "$instances_json" <<'PY'
import json
import sys

persistent = {
    "edge-01",
    "app-01",
    "db-01",
    "storage-01",
    "storage-02",
    "storage-03",
    "ops-01",
    "obs-01",
}
loadgen = "loadgen-01"

instances = json.load(open(sys.argv[1], encoding="utf-8"))
by_name = {item["name"]: item for item in instances}

missing = sorted(persistent - by_name.keys())
if missing:
    raise SystemExit(
        "Persistent Seoul runtime is incomplete; missing: " + ", ".join(missing)
    )

if loadgen in by_name:
    raise SystemExit(
        "loadgen-01 already exists; stop and reconcile live state before planning a new one"
    )

unexpected_runtime = sorted(
    name
    for name in by_name
    if name.startswith(("edge-", "app-", "db-", "storage-", "ops-", "obs-", "loadgen-"))
    and name not in persistent
)
if unexpected_runtime:
    raise SystemExit(
        "Unexpected runtime/loadgen instance names are present: "
        + ", ".join(unexpected_runtime)
    )

print("Persistent Seoul runtime: all 8 expected nodes present.")
print("Temporary loadgen-01: absent, as required before first M8 Phase 3 apply.")
PY

cat <<'EOF'

Operator quota/capacity review boundary:
- requested temporary delta: 1 x e2-standard-2 in asia-northeast1-a;
- expected VM demand: 2 E2 vCPUs, 1 instance, 20 GiB pd-standard boot disk;
- dedicated Tokyo subnet/router/Cloud NAT are planned with the VM;
- Cloud NAT uses AUTO_ONLY external addresses, so inspect relevant address quota headroom;
- this script is read-only and does not claim zonal stock availability merely because quota exists.

If quota/headroom is sufficient, continue with an exact OpenTofu plan from the retained
runtime state. Do not apply before reviewing that plan for temporary-loadgen-only changes.
EOF

echo 'PASS: M8 Phase 3 read-only loadgen preflight completed.'
