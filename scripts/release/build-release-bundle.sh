#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source_sha="${1:-}"
output_dir="${2:-$root/build/release/$source_sha}"

if [[ ! "$source_sha" =~ ^[0-9a-f]{40}$ ]]; then
  echo "source commit must be a full lowercase 40-character Git SHA" >&2
  exit 1
fi

mapfile -t jars < <(find "$root/app/target" -maxdepth 1 -type f -name 'application-review-platform-*.jar' -print | sort)
if [[ "${#jars[@]}" -ne 1 ]]; then
  echo "expected exactly one executable application JAR under app/target, found ${#jars[@]}" >&2
  printf '  %s\n' "${jars[@]:-}" >&2
  exit 1
fi

if [[ ! -f "$root/frontend/dist/index.html" ]]; then
  echo "frontend/dist/index.html is missing; build the Vite release first" >&2
  exit 1
fi

if find "$root/frontend/dist" -type l -print -quit | grep -q .; then
  echo "frontend/dist must not contain symbolic links" >&2
  exit 1
fi

rm -rf "$output_dir"
mkdir -p "$output_dir"

cp "${jars[0]}" "$output_dir/backend.jar"

tar \
  --sort=name \
  --mtime='UTC 1970-01-01' \
  --owner=0 \
  --group=0 \
  --numeric-owner \
  --format=gnu \
  -C "$root/frontend" \
  -cf - dist | gzip -n > "$output_dir/frontend.tar.gz"

python3 - "$source_sha" "$output_dir" <<'PY'
import hashlib
import json
import pathlib
import sys

source_sha = sys.argv[1]
output_dir = pathlib.Path(sys.argv[2])

def descriptor(name: str) -> dict[str, object]:
    path = output_dir / name
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    return {
        "file": name,
        "sha256": digest,
        "sizeBytes": path.stat().st_size,
    }

manifest = {
    "schemaVersion": 1,
    "releaseFormat": "arp-release-v1",
    "sourceCommit": source_sha,
    "backend": descriptor("backend.jar"),
    "frontend": descriptor("frontend.tar.gz"),
}

(output_dir / "release-manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY

bash "$root/scripts/release/verify-release-bundle.sh" "$output_dir" "$source_sha"
