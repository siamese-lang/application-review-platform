#!/usr/bin/env bash
set -euo pipefail

transfer_dir=${1:?usage: stage-release-on-ops.sh TRANSFER_DIR SHA DIGEST RUN_ID}
release_sha=${2:-}
release_digest=${3:-}
run_id=${4:-}
staging_root=${ARP_OPS_STAGING_ROOT:-/srv/arp/releases/incoming}
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

[[ $release_sha =~ ^[0-9a-f]{40}$ ]] || { echo 'invalid release SHA' >&2; exit 1; }
[[ $release_digest =~ ^sha256:[0-9a-f]{64}$ ]] || { echo 'invalid release digest' >&2; exit 1; }
[[ $run_id =~ ^[0-9]+$ ]] || { echo 'invalid workflow run ID' >&2; exit 1; }
[[ -d $transfer_dir && ! -L $transfer_dir ]] || { echo 'transfer directory is invalid' >&2; exit 1; }

verifier=${ARP_RELEASE_VERIFIER:-$repo_root/scripts/release/verify-release-bundle.sh}
if [[ -f "$transfer_dir/verify-release-bundle.sh" ]]; then
  verifier="$transfer_dir/verify-release-bundle.sh"
fi
bash "$verifier" "$transfer_dir" "$release_sha"
mkdir -p "$staging_root"
chmod 0700 "$staging_root"
final="$staging_root/$release_sha"
tmp=$(mktemp -d "$staging_root/.${release_sha}.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
install -m 0600 "$transfer_dir/backend.jar" "$tmp/backend.jar"
install -m 0600 "$transfer_dir/frontend.tar.gz" "$tmp/frontend.tar.gz"
install -m 0600 "$transfer_dir/release-manifest.json" "$tmp/release-manifest.json"
python3 - "$tmp/handoff.json" "$release_sha" "$release_digest" "$run_id" <<'PY'
import json, pathlib, sys
path, sha, digest, run_id = sys.argv[1:]
pathlib.Path(path).write_text(json.dumps({
    "sourceSha": sha,
    "ociDigest": digest,
    "releaseRepository": "ghcr.io/siamese-lang/application-review-platform-release",
    "githubWorkflowRunId": int(run_id),
}, sort_keys=True, indent=2) + "\n", encoding="utf-8")
PY
chmod 0600 "$tmp/handoff.json"
bash "$verifier" "$tmp" "$release_sha"

if [[ -e $final ]]; then
  [[ -d $final && ! -L $final ]] || { echo 'retained target is not a directory' >&2; exit 1; }
  bash "$verifier" "$final" "$release_sha"
  for file in backend.jar frontend.tar.gz release-manifest.json handoff.json; do
    [[ -f $final/$file && ! -L $final/$file ]] || { echo "invalid retained $file" >&2; exit 1; }
  done
  for file in backend.jar frontend.tar.gz release-manifest.json; do
    cmp -s "$tmp/$file" "$final/$file" || { echo "retained release content differs: $file" >&2; exit 1; }
  done
  python3 - "$final/handoff.json" "$release_sha" "$release_digest" <<'PY'
import json, pathlib, sys
path, sha, digest = sys.argv[1:]
try:
    receipt = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as exc:
    raise SystemExit(f"invalid retained handoff receipt: {exc}")
expected = {
    "sourceSha": sha,
    "ociDigest": digest,
    "releaseRepository": "ghcr.io/siamese-lang/application-review-platform-release",
}
for key, value in expected.items():
    if receipt.get(key) != value:
        raise SystemExit(f"retained release identity differs: {key}")
run_id = receipt.get("githubWorkflowRunId")
if not isinstance(run_id, int) or run_id < 1:
    raise SystemExit("retained handoff receipt has invalid githubWorkflowRunId")
PY
  echo "release already staged: $final"
  exit 0
fi
mv "$tmp" "$final"
trap - EXIT
echo "release staged: $final"
