#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile
from datetime import datetime, timezone


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def object_relpath(key: str) -> Path:
    digest = hashlib.sha256(key.encode("utf-8")).hexdigest()
    return Path("objects") / digest[:2] / digest


def write_json_atomic(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=path.parent,
        prefix=f".{path.name}.",
        delete=False,
    ) as handle:
        handle.write(encoded)
        temp_name = handle.name
    os.replace(temp_name, path)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Copy all objects from the M11 Garage bucket to an independent backup repository."
    )
    parser.add_argument("--endpoint", required=True)
    parser.add_argument("--bucket", required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args()

    access_key = os.environ.get("GARAGE_ACCESS_KEY", "")
    secret_key = os.environ.get("GARAGE_SECRET_KEY", "")
    if not access_key or not secret_key:
        raise SystemExit("GARAGE_ACCESS_KEY and GARAGE_SECRET_KEY are required")

    import boto3
    from botocore.config import Config

    root = args.output_root.resolve()
    root.mkdir(parents=True, exist_ok=True)

    client = boto3.client(
        "s3",
        endpoint_url=args.endpoint,
        region_name="garage",
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
    )

    started_at = utc_now()
    entries: list[dict] = []

    paginator = client.get_paginator("list_objects_v2")
    objects: list[dict] = []
    for page in paginator.paginate(Bucket=args.bucket):
        objects.extend(page.get("Contents", []))

    for item in sorted(objects, key=lambda row: row["Key"]):
        key = item["Key"]
        expected_size = int(item["Size"])
        relpath = object_relpath(key)
        target = root / relpath
        target.parent.mkdir(parents=True, exist_ok=True)

        response = client.get_object(Bucket=args.bucket, Key=key)
        digest = hashlib.sha256()
        size = 0
        temp = target.with_name(f".{target.name}.partial")
        try:
            with temp.open("wb") as output:
                for chunk in response["Body"].iter_chunks(chunk_size=1024 * 1024):
                    if not chunk:
                        continue
                    output.write(chunk)
                    digest.update(chunk)
                    size += len(chunk)
            if size != expected_size:
                raise RuntimeError(
                    f"size mismatch for {key!r}: list={expected_size} downloaded={size}"
                )
            os.replace(temp, target)
        finally:
            if temp.exists():
                temp.unlink()

        entries.append(
            {
                "object_key": key,
                "backup_file": relpath.as_posix(),
                "size": size,
                "sha256": digest.hexdigest(),
                "backup_timestamp": utc_now(),
            }
        )

    manifest = {
        "schema_version": 1,
        "bucket": args.bucket,
        "endpoint": args.endpoint,
        "started_at": started_at,
        "completed_at": utc_now(),
        "object_count": len(entries),
        "objects": entries,
    }
    write_json_atomic(args.manifest, manifest)

    manifest_sha = hashlib.sha256(args.manifest.read_bytes()).hexdigest()
    print(
        f"M11_OBJECT_BACKUP_OK bucket={args.bucket} objects={len(entries)} "
        f"manifest_sha256={manifest_sha}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
