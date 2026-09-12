#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
sha=0123456789abcdef0123456789abcdef01234567
digest=sha256:$(printf 'a%.0s' {1..64})

make_bundle() {
  local dir=$1 content=$2 manifest_sha=${3:-$sha}
  mkdir -p "$dir/dist"
  printf '<html>ok</html>' > "$dir/dist/index.html"
  tar -C "$dir" -czf "$dir/frontend.tar.gz" dist
  rm -rf "$dir/dist"
  printf '%s' "$content" > "$dir/backend.jar"
  python3 - "$dir" "$manifest_sha" <<'PY'
import hashlib,json,pathlib,sys
d=pathlib.Path(sys.argv[1])
def item(n):
 p=d/n; return {'file':n,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'sizeBytes':p.stat().st_size}
(d/'release-manifest.json').write_text(json.dumps({'schemaVersion':1,'releaseFormat':'arp-release-v1','sourceCommit':sys.argv[2],'backend':item('backend.jar'),'frontend':item('frontend.tar.gz')}))
PY
}
stage() { ARP_OPS_STAGING_ROOT="$tmp/incoming" bash "$root/scripts/deploy/stage-release-on-ops.sh" "$@"; }
make_bundle "$tmp/a" release-a
stage "$tmp/a" "$sha" "$digest" 42
bash "$root/scripts/release/verify-release-bundle.sh" "$tmp/incoming/$sha" "$sha"
stage "$tmp/a" "$sha" "$digest" 43
other_digest=sha256:$(printf 'b%.0s' {1..64})
! stage "$tmp/a" "$sha" "$other_digest" 44
make_bundle "$tmp/changed" changed
! stage "$tmp/changed" "$sha" "$digest" 42
make_bundle "$tmp/wrong-sha" x 1111111111111111111111111111111111111111
! stage "$tmp/wrong-sha" "$sha" "$digest" 42
cp -a "$tmp/a" "$tmp/tamper"; printf tamper >> "$tmp/tamper/backend.jar"
! stage "$tmp/tamper" "$sha" "$digest" 42
! stage "$tmp/a" "$sha" sha256:BAD 42
newsha=2222222222222222222222222222222222222222
! stage "$tmp/tamper" "$newsha" "$digest" 42
[[ ! -e "$tmp/incoming/$newsha" ]]
cp -a "$tmp/a" "$tmp/symlink"; rm "$tmp/symlink/backend.jar"; ln -s /etc/passwd "$tmp/symlink/backend.jar"
! stage "$tmp/symlink" "$sha" "$digest" 42
! grep -Eqi 'token|credential|private.?key|secret' "$tmp/incoming/$sha/handoff.json"
echo 'ops staging regression verified'
