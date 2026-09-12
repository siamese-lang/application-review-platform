#!/usr/bin/env python3
"""Static, fail-closed contract for the Phase 3B workflow."""
from pathlib import Path
import re

p = Path('.github/workflows/deploy-release.yml')
assert p.is_file()
t = p.read_text()
on_block = t.split('\non:\n', 1)[1].split('\nconcurrency:', 1)[0]
assert re.match(r'^  workflow_dispatch:', on_block)
assert not re.search(r'^  (push|pull_request|workflow_run|schedule):', on_block, re.M)
assert set(re.findall(r'^      ([a-z_]+):\n', on_block, re.M)) == {'release_sha', 'release_digest'}
assert on_block.count('required: true') == 2
assert 'group: m6-release-handoff' in t and 'cancel-in-progress: false' in t
permission_block = t.split('\npermissions:\n', 1)[1].split('\njobs:', 1)[0]
assert permission_block.strip() == 'contents: read\n  packages: read\n  id-token: write'
required = [
    '^[0-9a-f]{40}$', '^sha256:[0-9a-f]{64}$',
    'git cat-file -e', 'git merge-base --is-ancestor', 'origin/main',
    'ghcr.io/siamese-lang/application-review-platform-release',
    'resolved_digest', '== "$RELEASE_DIGEST"', 'org.opencontainers.image.source',
    'org.opencontainers.image.revision', 'scripts/release/verify-release-bundle.sh',
    'oras pull "$RELEASE_REPOSITORY@$RELEASE_DIGEST"',
    'oras-project/setup-oras@1d808f7d7f6995cc68b7bf507bfe5c5446e1dc9d',
    'google-github-actions/auth@7c6bc770dae815cd3e89ee6cdf493a5fab2cc093',
    'google-github-actions/setup-gcloud@26f734c2779b00b7dda794207734c511110a4368',
    'vars.GCP_WORKLOAD_IDENTITY_PROVIDER', 'vars.GCP_DEPLOY_SERVICE_ACCOUNT',
    'application-review-platform', 'ops-01', 'asia-northeast3-a',
    '--tunnel-through-iap', '--ssh-key-expire-after=5m',
    'GITHUB_REF', 'refs/heads/main', 'workflow_dispatch',
]
for needle in required:
    assert needle in t, needle
assert re.search(r'\$RELEASE_REPOSITORY:\$RELEASE_SHA', t)
for forbidden in ('credentials_json', 'activate-service-account', 'build-release-bundle.sh',
                  'mvnw', 'maven', 'npm ', 'vite', 'deploy/deploy-release.sh',
                  'deploy/rollback-release.sh', 'release-mechanics.py', 'systemctl restart arp',
                  'app-01', 'edge-01'):
    assert forbidden.lower() not in t.lower(), forbidden
print('delivery workflow contract verified')
