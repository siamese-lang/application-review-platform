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
import posixpath
import re
import sys
import tarfile

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

archive = bundle / "frontend.tar.gz"
found_index = False
try:
    with tarfile.open(archive, mode="r:gz") as tar:
        for member in tar.getmembers():
            name = member.name
            normalized = posixpath.normpath(name)
            if (
                not name
                or name.startswith("/")
                or normalized != name.rstrip("/")
                or normalized == ".."
                or normalized.startswith("../")
                or not (normalized == "dist" or normalized.startswith("dist/"))
            ):
                raise SystemExit(f"frontend archive contains an unsafe or unexpected path: {name}")
            if not (member.isfile() or member.isdir()):
                raise SystemExit(f"frontend archive contains a non-file entry: {name}")
            if normalized == "dist/index.html" and member.isfile():
                found_index = True
except (OSError, tarfile.TarError) as exc:
    raise SystemExit(f"invalid frontend archive: {exc}")

if not found_index:
    raise SystemExit("frontend archive does not contain regular file dist/index.html")
PY

echo "release bundle verified: $bundle_dir"
