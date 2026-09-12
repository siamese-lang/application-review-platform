#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
iam="$root/infra/opentofu/bootstrap/iam.tf"
variables="$root/infra/opentofu/bootstrap/variables.tf"

require_fixed() {
  local needle="$1" file="$2"
  grep -Fq -- "$needle" "$file" || { echo "Missing delivery identity contract: $needle" >&2; exit 1; }
}

require_fixed 'issuer_uri = "https://token.actions.githubusercontent.com"' "$iam"
grep -Eq '"google\.subject"[[:space:]]*=[[:space:]]*"assertion\.sub"' "$iam" || { echo "Missing google.subject mapping" >&2; exit 1; }
grep -Eq '"attribute\.repository_id"[[:space:]]*=[[:space:]]*"assertion\.repository_id"' "$iam" || { echo "Missing immutable repository_id mapping" >&2; exit 1; }
grep -Eq '"attribute\.repository_owner_id"[[:space:]]*=[[:space:]]*"assertion\.repository_owner_id"' "$iam" || { echo "Missing immutable repository_owner_id mapping" >&2; exit 1; }
require_fixed "assertion.repository == '\${var.github_repository}'" "$iam"
require_fixed "assertion.repository_id == '\${var.github_repository_id}'" "$iam"
require_fixed "assertion.repository_owner == '\${var.github_repository_owner}'" "$iam"
require_fixed "assertion.repository_owner_id == '\${var.github_repository_owner_id}'" "$iam"
require_fixed "assertion.ref == 'refs/heads/main'" "$iam"
require_fixed "assertion.workflow_ref == '\${var.github_deployment_workflow_ref}'" "$iam"
require_fixed "assertion.event_name == 'workflow_dispatch'" "$iam"

require_fixed 'default     = "siamese-lang/application-review-platform"' "$variables"
require_fixed 'default     = "1363362616"' "$variables"
require_fixed 'default     = "siamese-lang"' "$variables"
require_fixed 'default     = "174786754"' "$variables"
require_fixed 'default     = "siamese-lang/application-review-platform/.github/workflows/deploy-release.yml@refs/heads/main"' "$variables"

require_fixed 'resource "google_service_account" "github_deploy"' "$iam"
require_fixed 'account_id   = "arp-m6-github-deploy"' "$iam"
require_fixed 'role               = "roles/iam.workloadIdentityUser"' "$iam"
require_fixed 'attribute.repository_id/${var.github_repository_id}' "$iam"
require_fixed 'role    = "roles/compute.osAdminLogin"' "$iam"
require_fixed 'role    = "roles/iap.tunnelResourceAccessor"' "$iam"
require_fixed "expression  = \"destination.ip == '\${var.ops_private_ip}' && destination.port == 22\"" "$iam"
require_fixed 'default     = "10.40.0.50"' "$variables"
require_fixed 'service_account_id = google_service_account.ops.name' "$iam"

if grep -Fq 'resource "google_project_iam_member" "github_deploy_compute_viewer"' "$iam" ||
   grep -Fq 'role    = "roles/compute.viewer"' "$iam"; then
  echo "Dedicated GitHub identity must not receive redundant project-wide Compute Viewer access." >&2
  exit 1
fi

github_blocks="$(awk '/resource .*github_deploy/{capture=1} capture{print} /^}/{capture=0}' "$iam")"
if grep -Eq 'roles/(compute\.admin|compute\.networkAdmin|owner|editor)' <<<"$github_blocks"; then
  echo "Dedicated GitHub identity has a forbidden broad role." >&2
  exit 1
fi
if git -C "$root" grep -n 'resource "google_service_account_key"' -- '*.tf'; then
  echo "Service-account private-key resources are forbidden." >&2
  exit 1
fi
if git -C "$root" grep -nE '(BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|AGE-SECRET-KEY-|private_key(_data)?[[:space:]]*=)' -- 'infra/opentofu/bootstrap/*.tf' 'infra/opentofu/bootstrap/*.tfvars*'; then
  echo "Bootstrap configuration appears to contain private-key material." >&2
  exit 1
fi

echo "M6 delivery identity contract checks passed."
