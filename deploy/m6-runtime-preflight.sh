#!/usr/bin/env bash
set -euo pipefail

# Read-only M6 inspection. This script deliberately accepts no project/region overrides.
readonly PROJECT_ID=application-review-platform
readonly REGION=asia-northeast3
readonly REQUIRED_SERVICES=(
  compute.googleapis.com
  iam.googleapis.com
  iamcredentials.googleapis.com
  sts.googleapis.com
  iap.googleapis.com
  oslogin.googleapis.com
  cloudresourcemanager.googleapis.com
  serviceusage.googleapis.com
  cloudbilling.googleapis.com
)
readonly RUNTIME_NODES=(edge-01 app-01 db-01 storage-01 storage-02 storage-03 ops-01)

for command in gcloud python3; do
  command -v "$command" >/dev/null || { echo "Missing prerequisite: $command" >&2; exit 1; }
done

active_count=$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | sed '/^$/d' | wc -l)
(( active_count > 0 )) || { echo 'No active gcloud identity is available.' >&2; exit 1; }
echo 'Active gcloud identity: present (identity and credentials not printed).'

gcloud projects describe "$PROJECT_ID" --format='none'
echo "Target project is accessible: $PROJECT_ID"

billing_enabled=$(gcloud billing projects describe "$PROJECT_ID" --format='value(billingEnabled)')
[[ $billing_enabled == True ]] || { echo "Billing is not enabled for $PROJECT_ID." >&2; exit 1; }
echo 'Billing: enabled.'

enabled_services=$(gcloud services list --enabled --project="$PROJECT_ID" --format='value(config.name)')
missing=()
for service in "${REQUIRED_SERVICES[@]}"; do
  grep -Fxq "$service" <<<"$enabled_services" || missing+=("$service")
done
if ((${#missing[@]})); then
  printf 'Missing required enabled service: %s\n' "${missing[@]}" >&2
  echo 'Preflight is read-only; enable nothing automatically.' >&2
  exit 1
fi
echo 'Required APIs: enabled.'

project_quota=$(mktemp)
regional_quota=$(mktemp)
trap 'rm -f "$project_quota" "$regional_quota"' EXIT
gcloud compute project-info describe --project="$PROJECT_ID" --format=json >"$project_quota"
gcloud compute regions describe "$REGION" --project="$PROJECT_ID" --format=json >"$regional_quota"
echo 'Relevant project Compute quotas (metric, limit, usage):'
python3 - "$project_quota" <<'PY'
import json, sys
wanted = {"CPUS", "INSTANCES", "IN_USE_ADDRESSES", "SSD_TOTAL_GB"}
for quota in json.load(open(sys.argv[1], encoding="utf-8")).get("quotas", []):
    if quota.get("metric") in wanted:
        print(f"  {quota['metric']}: limit={quota.get('limit')} usage={quota.get('usage')}")
PY
echo "Relevant $REGION Compute quotas (metric, limit, usage):"
python3 - "$regional_quota" <<'PY'
import json, sys
wanted = {"CPUS", "CPUS_ALL_REGIONS", "INSTANCES", "IN_USE_ADDRESSES", "SSD_TOTAL_GB"}
for quota in json.load(open(sys.argv[1], encoding="utf-8")).get("quotas", []):
    if quota.get("metric") in wanted:
        print(f"  {quota['metric']}: limit={quota.get('limit')} usage={quota.get('usage')}")
PY
cat <<'EOF'
Operator quota review required: defaults request 7 instances, approximately 14 E2 vCPUs,
1 regional external address, and approximately 260 GiB of pd-balanced storage. Confirm
the returned metric scope and headroom; this script does not guess readiness or resize nodes.
EOF

present_nodes=$(gcloud compute instances list --project="$PROJECT_ID" --filter="name=($(IFS=' '; echo "${RUNTIME_NODES[*]}"))" --format='value(name)')
if [[ -n $present_nodes ]]; then
  echo 'Old runtime node names still present; clean recreation is unsafe:' >&2
  sed 's/^/  /' <<<"$present_nodes" >&2
  exit 1
fi
echo 'Old seven-node runtime names: absent.'

for account in arp-m4-ops arp-m4-workload; do
  gcloud iam service-accounts describe "$account@$PROJECT_ID.iam.gserviceaccount.com" --project="$PROJECT_ID" --format='none'
done
echo 'Retained owner-bootstrap service accounts: inspectable.'
echo 'Read-only M6 GCP readiness preflight completed; quota sufficiency still requires operator review.'
