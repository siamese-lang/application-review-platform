#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import tempfile


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts/backup/garage_object_backup.py"

spec = importlib.util.spec_from_file_location("m11_garage_object_backup", MODULE_PATH)
assert spec and spec.loader
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

first = module.object_relpath("applications/1/file.txt")
second = module.object_relpath("../applications/1/file.txt")
assert first.parts[0] == "objects"
assert len(first.parts) == 3
assert first != second
assert ".." not in first.parts

with tempfile.TemporaryDirectory() as temp:
    root = Path(temp)
    target = root / first
    target.parent.mkdir(parents=True)
    target.write_bytes(b"synthetic-m11-object")
    manifest = root / "manifest.json"
    module.write_json_atomic(
        manifest,
        {
            "schema_version": 1,
            "bucket": "synthetic",
            "object_count": 1,
            "objects": [
                {
                    "object_key": "applications/1/file.txt",
                    "backup_file": first.as_posix(),
                    "size": target.stat().st_size,
                    "sha256": __import__("hashlib").sha256(target.read_bytes()).hexdigest(),
                    "backup_timestamp": "2026-09-16T00:00:00Z",
                }
            ],
        },
    )
    parsed = json.loads(manifest.read_text(encoding="utf-8"))
    assert parsed["object_count"] == 1

print("M11 object-backup tooling unit contract: PASS")
