#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import time


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def target_sha256(client, bucket: str, key: str) -> tuple[int, str]:
    response = client.get_object(Bucket=bucket, Key=key)
    digest = hashlib.sha256()
    size = 0
    for chunk in response["Body"].iter_chunks(chunk_size=1024 * 1024):
        if not chunk:
            continue
        digest.update(chunk)
        size += len(chunk)
    return size, digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Restore and verify an M11 Garage checkpoint into a fresh DR bucket."
    )
    parser.add_argument("--endpoint", required=True)
    parser.add_argument("--bucket", required=True)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--manifest-sha256", required=True)
    args = parser.parse_args()

    if not (
        len(args.manifest_sha256) == 64
        and all(ch in "0123456789abcdef" for ch in args.manifest_sha256)
    ):
        raise SystemExit("manifest SHA-256 must be 64 lowercase hex characters")

    access_key = os.environ.get("GARAGE_ACCESS_KEY", "")
    secret_key = os.environ.get("GARAGE_SECRET_KEY", "")
    if not access_key or not secret_key:
        raise SystemExit("GARAGE_ACCESS_KEY and GARAGE_SECRET_KEY are required")

    import boto3
    from botocore.config import Config

    root = args.root.resolve()
    manifest = args.manifest.resolve()
    if not manifest.is_file():
        raise SystemExit("checkpoint manifest is missing")
    actual_manifest_sha = sha256_file(manifest)
    if actual_manifest_sha != args.manifest_sha256:
        raise SystemExit(
            f"manifest SHA-256 mismatch: expected={args.manifest_sha256} actual={actual_manifest_sha}"
        )

    data = json.loads(manifest.read_text(encoding="utf-8"))
    if data.get("schema_version") != 1:
        raise SystemExit("unsupported object-backup manifest schema")
    if data.get("bucket") != args.bucket:
        raise SystemExit(
            f"manifest bucket mismatch: expected={args.bucket!r} actual={data.get('bucket')!r}"
        )
    objects = data.get("objects")
    if not isinstance(objects, list):
        raise SystemExit("manifest objects must be a list")
    if data.get("object_count") != len(objects):
        raise SystemExit("manifest object_count does not match objects list")

    entries: list[tuple[str, Path, int, str]] = []
    seen: set[str] = set()
    for entry in objects:
        key = entry.get("object_key")
        rel = entry.get("backup_file")
        expected_size = int(entry.get("size", -1))
        expected_sha = entry.get("sha256")
        if not isinstance(key, str) or not key or key in seen:
            raise SystemExit(f"invalid or duplicate object key: {key!r}")
        seen.add(key)
        if not isinstance(rel, str) or not rel:
            raise SystemExit(f"invalid backup path for {key!r}")
        if not isinstance(expected_sha, str) or len(expected_sha) != 64:
            raise SystemExit(f"invalid SHA-256 for {key!r}")

        path = (root / rel).resolve()
        if root not in path.parents:
            raise SystemExit(f"backup path escapes root: {rel!r}")
        if not path.is_file():
            raise SystemExit(f"backup file is missing: {rel!r}")
        if path.stat().st_size != expected_size:
            raise SystemExit(f"source size mismatch for {key!r}")
        if sha256_file(path) != expected_sha:
            raise SystemExit(f"source SHA-256 mismatch for {key!r}")
        entries.append((key, path, expected_size, expected_sha))

    client = boto3.client(
        "s3",
        endpoint_url=args.endpoint,
        region_name="garage",
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
    )

    existing: list[str] = []
    paginator = client.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=args.bucket):
        existing.extend(item["Key"] for item in page.get("Contents", []))
    if existing:
        raise SystemExit(
            f"target DR bucket is not empty; refusing overwrite: {len(existing)} object(s)"
        )

    started = time.monotonic()
    for key, path, _, _ in entries:
        with path.open("rb") as handle:
            client.put_object(Bucket=args.bucket, Key=key, Body=handle)

    restored: list[str] = []
    for page in paginator.paginate(Bucket=args.bucket):
        restored.extend(item["Key"] for item in page.get("Contents", []))
    if sorted(restored) != sorted(seen):
        raise SystemExit(
            f"restored key set mismatch: expected={len(seen)} actual={len(restored)}"
        )

    for key, _, expected_size, expected_sha in entries:
        size, digest = target_sha256(client, args.bucket, key)
        if size != expected_size:
            raise SystemExit(f"restored size mismatch for {key!r}")
        if digest != expected_sha:
            raise SystemExit(f"restored SHA-256 mismatch for {key!r}")

    elapsed_ms = int((time.monotonic() - started) * 1000)
    print(f"M11_FULL_DR_OBJECT_COUNT={len(entries)}")
    print(f"M11_FULL_DR_OBJECT_MANIFEST_SHA256={actual_manifest_sha}")
    print(f"M11_FULL_DR_OBJECT_RESTORE_MS={elapsed_ms}")
    print("M11_FULL_DR_OBJECT_RESTORE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
