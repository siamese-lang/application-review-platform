#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path


def sha256_stream(body) -> tuple[int, str]:
    digest = hashlib.sha256()
    size = 0
    for chunk in body.iter_chunks(chunk_size=1024 * 1024):
        if not chunk:
            continue
        digest.update(chunk)
        size += len(chunk)
    return size, digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify restored M11 DR database invariants and checkpoint attachment integrity."
    )
    parser.add_argument("--db-snapshot", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--manifest-sha256", required=True)
    parser.add_argument("--endpoint", required=True)
    parser.add_argument("--bucket", required=True)
    parser.add_argument("--expected-checkpoint-available", type=int, required=True)
    args = parser.parse_args()

    access_key = os.environ.get("GARAGE_ACCESS_KEY", "")
    secret_key = os.environ.get("GARAGE_SECRET_KEY", "")
    if not access_key or not secret_key:
        raise SystemExit("GARAGE_ACCESS_KEY and GARAGE_SECRET_KEY are required")
    if not (
        len(args.manifest_sha256) == 64
        and all(ch in "0123456789abcdef" for ch in args.manifest_sha256)
    ):
        raise SystemExit("manifest SHA-256 must be 64 lowercase hex characters")

    db = json.loads(args.db_snapshot.read_text(encoding="utf-8"))
    zero_invariants = [
        "orphan_applications",
        "history_status_mismatch",
        "terminal_history_missing",
        "reviewer_state_mismatch",
        "audit_subject_mismatch",
        "history_actor_role_mismatch",
        "pending_attachments",
        "failed_attachments",
        "delete_pending_attachments",
    ]
    for name in zero_invariants:
        value = int(db.get(name, -1))
        if value != 0:
            raise SystemExit(f"database invariant failed: {name}={value}")

    attachments = db.get("checkpoint_available_attachments")
    if not isinstance(attachments, list):
        raise SystemExit("checkpoint_available_attachments must be a list")
    if len(attachments) != args.expected_checkpoint_available:
        raise SystemExit(
            "checkpoint AVAILABLE attachment count mismatch: "
            f"expected={args.expected_checkpoint_available} actual={len(attachments)}"
        )

    manifest_path = args.manifest.resolve()
    if not manifest_path.is_file():
        raise SystemExit("checkpoint manifest is missing")
    actual_manifest_sha = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
    if actual_manifest_sha != args.manifest_sha256:
        raise SystemExit(
            f"manifest SHA-256 mismatch: expected={args.manifest_sha256} actual={actual_manifest_sha}"
        )
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != 1:
        raise SystemExit("unsupported manifest schema")
    if manifest.get("bucket") != args.bucket:
        raise SystemExit("manifest bucket mismatch")
    objects = manifest.get("objects")
    if not isinstance(objects, list) or manifest.get("object_count") != len(objects):
        raise SystemExit("manifest object_count does not match objects")

    manifest_by_key: dict[str, dict] = {}
    for row in objects:
        key = row.get("object_key")
        if not isinstance(key, str) or not key or key in manifest_by_key:
            raise SystemExit(f"invalid or duplicate manifest object key: {key!r}")
        manifest_by_key[key] = row

    seen_db_keys: set[str] = set()
    for row in attachments:
        key = row.get("object_key")
        if not isinstance(key, str) or not key or key in seen_db_keys:
            raise SystemExit(f"invalid or duplicate DB object key: {key!r}")
        seen_db_keys.add(key)
        manifest_row = manifest_by_key.get(key)
        if manifest_row is None:
            raise SystemExit(f"checkpoint AVAILABLE attachment missing from manifest: {key!r}")
        if int(row.get("size_bytes", -1)) != int(manifest_row.get("size", -2)):
            raise SystemExit(f"DB/manifest size mismatch for {key!r}")
        if row.get("sha256") != manifest_row.get("sha256"):
            raise SystemExit(f"DB/manifest SHA-256 mismatch for {key!r}")

    import boto3
    from botocore.config import Config

    client = boto3.client(
        "s3",
        endpoint_url=args.endpoint,
        region_name="garage",
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
    )

    target_keys: set[str] = set()
    paginator = client.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=args.bucket):
        target_keys.update(item["Key"] for item in page.get("Contents", []))
    missing_manifest_keys = sorted(set(manifest_by_key) - target_keys)
    if missing_manifest_keys:
        raise SystemExit(
            f"restored target is missing {len(missing_manifest_keys)} checkpoint object(s)"
        )

    verified_manifest_objects = 0
    for key, row in manifest_by_key.items():
        response = client.get_object(Bucket=args.bucket, Key=key)
        size, digest = sha256_stream(response["Body"])
        if size != int(row["size"]):
            raise SystemExit(f"target size mismatch for checkpoint object {key!r}")
        if digest != row["sha256"]:
            raise SystemExit(f"target SHA-256 mismatch for checkpoint object {key!r}")
        verified_manifest_objects += 1

    print(f"M11_FULL_DR_ORPHAN_APPLICATIONS={db['orphan_applications']}")
    print(f"M11_FULL_DR_HISTORY_STATUS_MISMATCH={db['history_status_mismatch']}")
    print(f"M11_FULL_DR_TERMINAL_HISTORY_MISSING={db['terminal_history_missing']}")
    print(f"M11_FULL_DR_REVIEWER_STATE_MISMATCH={db['reviewer_state_mismatch']}")
    print(f"M11_FULL_DR_AUDIT_SUBJECT_MISMATCH={db['audit_subject_mismatch']}")
    print(f"M11_FULL_DR_HISTORY_ACTOR_ROLE_MISMATCH={db['history_actor_role_mismatch']}")
    print(f"M11_FULL_DR_PENDING_ATTACHMENTS={db['pending_attachments']}")
    print(f"M11_FULL_DR_FAILED_ATTACHMENTS={db['failed_attachments']}")
    print(f"M11_FULL_DR_DELETE_PENDING_ATTACHMENTS={db['delete_pending_attachments']}")
    print(f"M11_FULL_DR_CHECKPOINT_AVAILABLE_ATTACHMENTS={len(attachments)}")
    print(f"M11_FULL_DR_CHECKPOINT_MANIFEST_OBJECTS={len(manifest_by_key)}")
    print(f"M11_FULL_DR_TARGET_MANIFEST_OBJECTS_VERIFIED={verified_manifest_objects}")
    print(f"M11_FULL_DR_MANIFEST_SHA256={actual_manifest_sha}")
    print("M11_FULL_DR_INTEGRITY=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
