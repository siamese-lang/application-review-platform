#!/usr/bin/env bash
set -euo pipefail

bundle_dir="${1:-}"
expected_sha="${2:-}"

if [[ -z "$bundle_dir" || ! -d "$bundle_dir" ]]; then
  echo "usage: verify-release-bundle.sh <bundle-directory> [expected-full-git-sha]" >&2
  exit 1
fi

for file in backend.jar frontend.tar.gz release-manifest.json; do
  if [[ ! -f "$bundle_dir/$file" || -L "$bundle_dir/$file" ]]; then
    echo "bundle file is missing or is a symbolic link: $file" >&2
    exit 1
  fi
done

python3 - "$bundle_dir" "$expected_sha" <<'PY'
import hashlib
import json
import pathlib
import re
import sys

bundle = pathlib.Path(sys.argv[1])
expected_sha = sys.argv[2]

manifest_path = bundle / "release-manifest.json"
try:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as exc:
    raise SystemExit(f"invalid release manifest: {exc}")

if set(manifest) != {"schemaVersion", "releaseFormat", "sourceCommit", "backend", "frontend"}:
    raise SystemExit("release manifest has unexpected top-level fields")
if manifest["schemaVersion"] != 1:
    raise SystemExit("unsupported release manifest schemaVersion")
if manifest["releaseFormat"] != "arp-release-v1":
    raise SystemExit("unsupported release format")

source_commit = manifest["sourceCommit"]
if not isinstance(source_commit, str) or not re.fullmatch(r"[0-9a-f]{40}", source_commit):
    raise SystemExit("sourceCommit must be a full lowercase Git SHA")
if expected_sha and source_commit != expected_sha:
    raise SystemExit(f"sourceCommit mismatch: expected {expected_sha}, got {source_commit}")

for logical_name, expected_file in (("backend", "backend.jar"), ("frontend", "frontend.tar.gz")):
    entry = manifest.get(logical_name)
    if not isinstance(entry, dict) or set(entry) != {"file", "sha256", "sizeBytes"}:
        raise SystemExit(f"invalid {logical_name} descriptor")
    if entry["file"] != expected_file:
        raise SystemExit(f"{logical_name} file must be {expected_file}")
    path = bundle / expected_file
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if entry["sha256"] != digest:
        raise SystemExit(f"{logical_name} SHA-256 mismatch")
    if entry["sizeBytes"] != path.stat().st_size:
        raise SystemExit(f"{logical_name} size mismatch")
PY

while IFS= read -r entry; do
  case "$entry" in
    dist|dist/*) ;;
    *)
      echo "frontend archive contains an unexpected path: $entry" >&2
      exit 1
      ;;
  esac
  if [[ "$entry" == /* || "$entry" == ../* || "$entry" == *"/../"* || "$entry" == *"/.." ]]; then
    echo "frontend archive contains an unsafe path: $entry" >&2
    exit 1
  fi
done < <(tar -tzf "$bundle_dir/frontend.tar.gz")

if ! tar -tzf "$bundle_dir/frontend.tar.gz" | grep -Fxq 'dist/index.html'; then
  echo "frontend archive does not contain dist/index.html" >&2
  exit 1
fi

echo "release bundle verified: $bundle_dir"
