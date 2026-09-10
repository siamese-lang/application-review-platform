#!/usr/bin/env bash
set -euo pipefail

required_files=(
  AGENTS.md
  docs/product/PRODUCT.md
  docs/domain/DOMAIN.md
  docs/architecture/ARCHITECTURE.md
  docs/security/SECURITY.md
  docs/data/DATA.md
  docs/operations/BACKUP_RECOVERY.md
  docs/workload/WORKLOAD.md
  docs/NON_GOALS.md
  docs/FREEZE_RECORD.md
)

for file in "${required_files[@]}"; do
  [[ -s "$file" ]] || { echo "Missing or empty required file: $file" >&2; exit 1; }
done

grep -q 'Status: FROZEN' docs/product/PRODUCT.md
grep -q 'DRAFT' docs/domain/DOMAIN.md
grep -q 'SUBMITTED' docs/domain/DOMAIN.md
grep -q 'PostgreSQL' docs/architecture/ARCHITECTURE.md
grep -q 'Garage' docs/architecture/ARCHITECTURE.md
grep -q 'OpenTofu' docs/architecture/ARCHITECTURE.md
grep -q 'Replication is not backup' docs/operations/BACKUP_RECOVERY.md
grep -q 'Kubernetes' docs/NON_GOALS.md

echo 'M0 repository baseline verification passed.'
