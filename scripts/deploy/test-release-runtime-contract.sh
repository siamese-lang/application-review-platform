#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

bash -n deploy/configure-runtime.sh deploy/deploy-release.sh deploy/rollback-release.sh deploy/bootstrap-ip-tls.sh deploy/cloud-smoke.sh
python3 -m py_compile scripts/deploy/release-mechanics.py
grep -Fq 'unset ARP_APP_JAR ARP_APP_VERSION' deploy/configure-runtime.sh

if ARP_ROLLBACK_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  deploy/rollback-release.sh >/dev/null 2>&1; then
  echo 'rollback proceeded without schema-compatibility acknowledgement' >&2
  exit 1
fi

if grep -En 'mvnw|maven|npm|vite|app/target|ARP_APP_JAR' deploy/deploy-release.sh; then
  echo 'final release wrapper must not build or discover a local JAR' >&2
  exit 1
fi
grep -Fq '^[0-9a-f]{40}$' deploy/deploy-release.sh
grep -Fq 'verify-release-bundle.sh' deploy/deploy-release.sh
grep -Fq 'release.yml' deploy/deploy-release.sh
grep -Fq 'rollback.yml' deploy/rollback-release.sh
grep -Fq 'ARP_ROLLBACK_SCHEMA_COMPATIBLE' deploy/rollback-release.sh

for script in deploy/deploy-release.sh deploy/rollback-release.sh deploy/bootstrap-ip-tls.sh; do
  grep -Fq 'root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)' "$script"
  if grep -Fq 'git rev-parse --show-toplevel' "$script"; then
    echo "ops entry point still depends on caller working directory: $script" >&2
    exit 1
  fi
done

grep -Fq 'Wait for activated backend API readiness' config/ansible/release.yml
grep -Fq 'http://127.0.0.1:8080/api/v1/programs?size=1' config/ansible/release.yml
grep -Fq 'Wait for rolled-back backend API readiness' config/ansible/rollback.yml
grep -Fq 'http://127.0.0.1:8080/api/v1/programs?size=1' config/ansible/rollback.yml

python3 - <<'PY'
from pathlib import Path
release = Path("config/ansible/release.yml").read_text()
assert release.index("Wait for activated backend API readiness") < release.index("Activate frontend after backend succeeds")
PY

for endpoint in   '/api/v1/auth/csrf'   '/api/v1/auth/register'   '/api/v1/auth/login'   '/api/v1/programs'   '/api/v1/applications'   '/api/v1/review/applications'; do
  grep -Fq "$endpoint" deploy/cloud-smoke.sh
done
grep -Fq 'id="root"' deploy/cloud-smoke.sh
grep -Fq 'sha256sum' deploy/cloud-smoke.sh
grep -Fq 'IN_REVIEW' deploy/cloud-smoke.sh
grep -Fq 'APPROVED' deploy/cloud-smoke.sh
if grep -Fq '$BASE_URL/login' deploy/cloud-smoke.sh || grep -Fq '$BASE_URL/applications' deploy/cloud-smoke.sh; then
  echo 'cloud smoke still targets the removed Thymeleaf browser routes' >&2
  exit 1
fi
if grep -Eq '(^|[[:space:]])(-k|--insecure)([[:space:]]|$)' deploy/cloud-smoke.sh; then
  echo 'cloud smoke disables TLS verification' >&2
  exit 1
fi

[[ $(grep -c '^  any_errors_fatal: true$' config/ansible/release.yml) -eq 6 ]] || {
  echo 'every release play must abort the remaining playbook on failure' >&2
  exit 1
}
[[ $(grep -c '^  any_errors_fatal: true$' config/ansible/rollback.yml) -eq 4 ]] || {
  echo 'every rollback play must abort the remaining playbook on failure' >&2
  exit 1
}

if ARP_RELEASE_BUNDLE_DIR=/tmp ARP_RELEASE_SHA=short \
  deploy/deploy-release.sh >/dev/null 2>&1; then
  echo 'deployment accepted a non-full release SHA' >&2
  exit 1
fi

if grep -Fq 'Require a built application artifact' config/ansible/roles/app/tasks/main.yml; then
  echo 'normal application provisioning still requires a local JAR' >&2
  exit 1
fi
grep -Fq 'when: app_jar_source | length > 0' config/ansible/roles/app/tasks/main.yml
if python3 - <<'PY'
from pathlib import Path
import re
text = Path("config/ansible/roles/edge/tasks/main.yml").read_text()
raise SystemExit(0 if re.search(r"path: /opt/arp/frontend/current[^\n]*\n[^\n]*state: directory", text) else 1)
PY
then
  echo 'edge role recreates the active frontend pointer as a directory' >&2
  exit 1
fi
grep -Fq 'ExecStart=/usr/bin/java -jar /opt/arp/application.jar' config/ansible/roles/app/templates/arp.service.j2
grep -Fq 'root /opt/arp/frontend/current;' config/ansible/roles/edge/templates/arp.conf.j2

for forbidden in ghcr.io gcloud google-github-actions workflow_dispatch; do
  if grep -En "$forbidden" deploy/deploy-release.sh deploy/rollback-release.sh config/ansible/release.yml config/ansible/rollback.yml; then
    echo "Phase 2B unexpectedly contains GitHub/GCP delivery mutation: $forbidden" >&2
    exit 1
  fi
done

echo 'M6 release runtime static contract passed'
