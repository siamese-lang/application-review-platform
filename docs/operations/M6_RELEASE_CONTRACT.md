# M6 Release Artifact Contract

Status: ACTIVE M6 CONTRACT

M6 Phase 1 binds the backend and frontend produced from one reviewed source commit into one logical release.

## Identity

The release identity is the full lowercase 40-character Git commit SHA.

The retained OCI reference is:

`ghcr.io/siamese-lang/application-review-platform-release:<full-sha>`

Deployment and rollback later resolve the OCI digest and must not depend on a floating `latest` tag.

## Bundle contents

Each release contains exactly three logical payloads:

- `backend.jar`: executable Spring Boot JAR;
- `frontend.tar.gz`: deterministic archive of the Vite `dist/` tree;
- `release-manifest.json`: versioned manifest binding the two payloads to the source SHA.

Manifest schema v1 records:

- `schemaVersion`;
- `releaseFormat`;
- `sourceCommit`;
- backend filename, byte size, and SHA-256;
- frontend filename, byte size, and SHA-256.

No build timestamp, credential, environment secret, runtime hostname, or GCP identifier is stored in the manifest.

## Determinism boundary

`scripts/release/build-release-bundle.sh` deterministically assembles a bundle from already-built backend/frontend payloads:

- the executable JAR must resolve to exactly one file;
- frontend archive entries are sorted;
- archive ownership and mtime are normalized;
- gzip timestamp metadata is disabled;
- manifest JSON key order/format is stable.

This guarantees deterministic **assembly from the same input payloads**. It does not claim that Maven or Vite independently reproduce byte-identical outputs across arbitrary toolchains or environments.

## Verification

`scripts/release/verify-release-bundle.sh` rejects:

- missing/symlink payloads;
- unknown manifest schema/fields;
- source-SHA mismatch;
- payload checksum/size mismatch;
- frontend archive paths outside `dist/`;
- frontend archives without `dist/index.html`.

PR CI builds the application/frontend, assembles the bundle twice from the same payloads, compares the outputs, and verifies the manifest/checksums.

## GHCR publication

Publication occurs only on a `push` to `main` after the completed M5 checks and the M6 bundle-verification job succeed. A main revision that changes only `docs/**` and/or `README.md` does not create another runtime release artifact; such commits do not change deployable/runtime material.

The publish job:

- uses ORAS CLI 1.3.3 through the setup-oras action pinned to commit `1d808f7d7f6995cc68b7bf507bfe5c5446e1dc9d`;
- authenticates to GHCR with the repository-scoped GitHub Actions token;
- receives `packages: write` only in the publication job;
- publishes an OCI artifact, not a containerized Spring runtime;
- uses the full source SHA as the only release tag;
- skips docs/README-only main revisions to avoid retaining redundant byte-identical runtime payloads;
- records the OCI digest;
- pulls the artifact back by digest and runs the same bundle verifier.

If the SHA tag already exists, the workflow does not overwrite it. It pulls and verifies the existing artifact against the same expected source SHA instead.

## Media types

Artifact type:

`application/vnd.siameselang.arp.release.v1`

Layers:

- manifest: `application/vnd.siameselang.arp.release-manifest.v1+json`;
- backend: `application/vnd.siameselang.arp.backend.v1+java-archive`;
- frontend: `application/vnd.siameselang.arp.frontend.v1+tar+gzip`.

These media types describe repository artifacts only and do not alter the VM/JAR/Nginx runtime architecture.

## Evidence boundary

Phase 1 is enabling evidence.

Successfully publishing a GHCR artifact is **not** enough to promote the M6 portfolio candidate. The portfolio claim requires the later real deployment and schema-compatible rollback drill defined in the active M6 plan.

## Phase 2B runtime path

Phase 2B starts with an exact, already downloaded bundle on the controlled operations
path. `deploy/configure-runtime.sh` configures hosts without building or activating a
release. `deploy/deploy-release.sh` verifies the local bundle against an explicit full
SHA, then Ansible stages and verifies both component hosts before activating the
backend, restarting `arp.service`, and finally activating the frontend.

The repository-managed mechanics and the same bundle verifier are installed on app
and edge hosts under `/usr/local/lib/arp`. Retained bundles and component state remain
under `/opt/arp/releases/<full-sha>` and `/opt/arp/release-state`; stable systemd and
Nginx pointers do not change.

Rollback requires an explicit full SHA and the operator acknowledgement
`ARP_ROLLBACK_SCHEMA_COMPATIBLE=true`. Both hosts verify that SHA as their recorded,
checksum-valid previous release before either pointer changes. Switching then follows
frontend, backend, and backend restart order. This performs no database rollback and
does not claim cross-host atomicity.
