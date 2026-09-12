#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

bash -n deploy/configure-runtime.sh deploy/deploy-release.sh deploy/rollback-release.sh
python3 -m py_compile scripts/deploy/release-mechanics.py

if ARP_ROLLBACK_SHA=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  deploy/rollback-release.sh >/dev/null 2>&1; then
  echo 'rollback proceeded without schema-compatibility acknowledgement' >&2
  exit 1
fi

if rg -n 'mvnw|maven|npm|vite|app/target|ARP_APP_JAR' deploy/deploy-release.sh; then
  echo 'final release wrapper must not build or discover a local JAR' >&2
  exit 1
fi
grep -Fq '^[0-9a-f]{40}$' deploy/deploy-release.sh
grep -Fq 'verify-release-bundle.sh' deploy/deploy-release.sh
grep -Fq 'release.yml' deploy/deploy-release.sh
grep -Fq 'rollback.yml' deploy/rollback-release.sh
grep -Fq 'ARP_ROLLBACK_SCHEMA_COMPATIBLE' deploy/rollback-release.sh
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
if rg -U 'path: /opt/arp/frontend/current[^\n]*\n[^\n]*state: directory' config/ansible/roles/edge/tasks/main.yml; then
  echo 'edge role recreates the active frontend pointer as a directory' >&2
  exit 1
fi
grep -Fq 'ExecStart=/usr/bin/java -jar /opt/arp/application.jar' config/ansible/roles/app/templates/arp.service.j2
grep -Fq 'root /opt/arp/frontend/current;' config/ansible/roles/edge/templates/arp.conf.j2

for forbidden in ghcr.io gcloud google-github-actions workflow_dispatch; do
  if rg -n "$forbidden" deploy/deploy-release.sh deploy/rollback-release.sh config/ansible/release.yml config/ansible/rollback.yml; then
    echo "Phase 2B unexpectedly contains GitHub/GCP delivery mutation: $forbidden" >&2
    exit 1
  fi
done

echo 'M6 release runtime static contract passed'
