#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify an M11 Garage object-backup manifest.")
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args()

    root = args.root.resolve()
    manifest_path = args.manifest.resolve()
    data = json.loads(manifest_path.read_text(encoding="utf-8"))

    if data.get("schema_version") != 1:
        raise SystemExit("unsupported object-backup manifest schema")
    objects = data.get("objects")
    if not isinstance(objects, list):
        raise SystemExit("manifest objects must be a list")
    if data.get("object_count") != len(objects):
        raise SystemExit("manifest object_count does not match objects list")

    seen: set[str] = set()
    for entry in objects:
        key = entry.get("object_key")
        rel = entry.get("backup_file")
        if not isinstance(key, str) or not key:
            raise SystemExit("manifest entry has invalid object_key")
        if key in seen:
            raise SystemExit(f"duplicate object key in manifest: {key!r}")
        seen.add(key)
        if not isinstance(rel, str) or not rel:
            raise SystemExit(f"manifest entry has invalid backup_file: {key!r}")

        path = (root / rel).resolve()
        if root not in path.parents:
            raise SystemExit(f"backup path escapes root: {rel!r}")
        if not path.is_file():
            raise SystemExit(f"backup file is missing: {rel!r}")

        size = path.stat().st_size
        if size != int(entry.get("size", -1)):
            raise SystemExit(f"size mismatch for {key!r}")
        if sha256_file(path) != entry.get("sha256"):
            raise SystemExit(f"SHA-256 mismatch for {key!r}")
        if not entry.get("backup_timestamp"):
            raise SystemExit(f"backup timestamp missing for {key!r}")

    manifest_sha = sha256_file(manifest_path)
    print(
        f"M11_OBJECT_BACKUP_VERIFY=PASS objects={len(objects)} "
        f"manifest_sha256={manifest_sha}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
