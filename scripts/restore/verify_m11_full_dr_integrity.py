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
        description=(
            "Verify the M11 DR missing business invariants and checkpoint "
            "DB/manifest/Garage attachment consistency."
        )
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
        "reviewer_state_mismatch",
        "reviewer_history_ownership_mismatch",
        "history_transition_mismatch",
        "history_chain_mismatch",
        "audit_subject_mismatch",
        "audit_actor_ownership_mismatch",
        "checkpoint_attachment_uploader_mismatch",
        "checkpoint_pending_attachments",
        "checkpoint_failed_attachments",
        "checkpoint_delete_pending_attachments",
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

    verified_attachment_objects = 0
    for row in attachments:
        key = row["object_key"]
        try:
            response = client.get_object(Bucket=args.bucket, Key=key)
        except client.exceptions.NoSuchKey as exc:
            raise SystemExit(
                f"checkpoint attachment object missing from restored target: {key!r}"
            ) from exc
        size, digest = sha256_stream(response["Body"])
        expected_size = int(row["size_bytes"])
        expected_sha = row["sha256"]
        if size != expected_size:
            raise SystemExit(f"target size mismatch for checkpoint attachment {key!r}")
        if digest != expected_sha:
            raise SystemExit(f"target SHA-256 mismatch for checkpoint attachment {key!r}")
        verified_attachment_objects += 1

    post_checkpoint_target_objects = len(target_keys - set(manifest_by_key))
    print(f"M11_FULL_DR_REVIEWER_STATE_MISMATCH={db['reviewer_state_mismatch']}")
    print(
        "M11_FULL_DR_REVIEWER_HISTORY_OWNERSHIP_MISMATCH="
        f"{db['reviewer_history_ownership_mismatch']}"
    )
    print(f"M11_FULL_DR_HISTORY_TRANSITION_MISMATCH={db['history_transition_mismatch']}")
    print(f"M11_FULL_DR_HISTORY_CHAIN_MISMATCH={db['history_chain_mismatch']}")
    print(f"M11_FULL_DR_AUDIT_SUBJECT_MISMATCH={db['audit_subject_mismatch']}")
    print(
        "M11_FULL_DR_AUDIT_ACTOR_OWNERSHIP_MISMATCH="
        f"{db['audit_actor_ownership_mismatch']}"
    )
    print(
        "M11_FULL_DR_CHECKPOINT_ATTACHMENT_UPLOADER_MISMATCH="
        f"{db['checkpoint_attachment_uploader_mismatch']}"
    )
    print(
        "M11_FULL_DR_CHECKPOINT_PENDING_ATTACHMENTS="
        f"{db['checkpoint_pending_attachments']}"
    )
    print(
        "M11_FULL_DR_CHECKPOINT_FAILED_ATTACHMENTS="
        f"{db['checkpoint_failed_attachments']}"
    )
    print(
        "M11_FULL_DR_CHECKPOINT_DELETE_PENDING_ATTACHMENTS="
        f"{db['checkpoint_delete_pending_attachments']}"
    )
    print(
        "M11_FULL_DR_POST_CHECKPOINT_ATTACHMENT_ROWS="
        f"{db.get('post_checkpoint_attachment_rows', 0)}"
    )
    print(f"M11_FULL_DR_CHECKPOINT_AVAILABLE_ATTACHMENTS={len(attachments)}")
    print(f"M11_FULL_DR_CHECKPOINT_MANIFEST_OBJECTS={len(manifest_by_key)}")
    print(
        "M11_FULL_DR_CHECKPOINT_ATTACHMENT_OBJECTS_VERIFIED="
        f"{verified_attachment_objects}"
    )
    print(f"M11_FULL_DR_TARGET_OBJECTS_CURRENT={len(target_keys)}")
    print(
        "M11_FULL_DR_TARGET_OBJECTS_NOT_IN_CHECKPOINT_MANIFEST="
        f"{post_checkpoint_target_objects}"
    )
    print(f"M11_FULL_DR_MANIFEST_SHA256={actual_manifest_sha}")
    print("M11_FULL_DR_INTEGRITY=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
