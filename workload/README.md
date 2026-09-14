# M8 workload foundation

This directory is the repository-owned workload boundary for M8.

Phase 1 establishes structure only. It does **not** contain a representative baseline result,
does not create dataset M, and does not justify any performance change.

## Load generator contract

`loadgen-01` is a temporary private VM created only when OpenTofu is invoked with
`enable_loadgen=true`.

Default placement follows ADR-004:

- region: `asia-northeast1` (Tokyo);
- zone: `asia-northeast1-a`;
- no public IP;
- outbound package/test traffic through a dedicated Cloud NAT;
- private administration from the existing `ops-01` path through the shared
  `arp-managed` SSH firewall contract;
- never colocated on edge/app/db/storage/ops/observability hosts.

The persistent eight-node Seoul runtime remains in `local.nodes`; the temporary load
generator is intentionally modeled separately.

## Runtime prerequisite

Pinned k6 runtime metadata lives in `tool-versions.env`.

Phase 1 pins the tool but does not install it live. Live installation/configuration belongs
to the reviewed M8 activation phase after quota and OpenTofu plan checks.

## k6 foundation script

`k6/foundation-smoke.js` exists only to prove repository structure, syntax, stable tags,
and environment-driven target configuration.

It is **not** W1. The real W1 workload is added after deterministic synthetic users/data and
the real session/CSRF helpers exist.

No credentials, cookies, CSRF values, session IDs, request IDs, application IDs, or user
identifiers belong in k6 metric tags.

## Run manifest

`run-manifest.schema.json` defines the minimum reproducibility metadata for retained M8
runs. `run-manifest.example.json` uses sentinel values and is not measurement evidence.

A retained run must record the exact source/release identity, dataset seed/version,
load-generator placement, workload profile, runtime identity, and timestamps.

## Deterministic dataset bundles

Phase 2 adds repository-owned bulk fixture generation for database scale.

Profiles are frozen in `datasets/profiles.json`:

- S: 10,000 applications;
- M: 100,000 applications;
- L: 500,000 applications.

Generate a bundle without touching a database:

```bash
python3 scripts/workload/generate-synthetic-dataset.py \
  --profile S \
  --seed 20260914 \
  --output build/workload/S
```

Each bundle contains programs, non-login synthetic users, applications, status histories,
audit events, a guarded `load.sql`, a `verify.sql`, and a manifest with row counts and
SHA-256 values.

The generated namespace uses IDs from 8,000,000,000 through 8,999,999,999. The loader
refuses to proceed without an explicit psql confirmation variable and checks for namespace
collisions before deleting only M8-owned rows.

Bulk-generated users intentionally cannot authenticate. Real session/CSRF workload users
remain runtime-managed synthetic accounts. This prevents committed dataset artifacts from
containing reusable credentials.

Phase 2 does not seed attachment objects. The 5% attachment workload uses bounded runtime
fixtures later, so database scale generation does not pretend that Garage object data exists.
