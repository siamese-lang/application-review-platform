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


## W1 workload harness smoke

`k6/w1-smoke.js` is the Phase 4 correctness smoke. It is deliberately not a performance
baseline.

The repository-owned entrypoint is:

```bash
bash workload/run-w1.sh
```

The operator environment must already provide:

- `ARP_EXPECTED_SOURCE_SHA` for the exact reviewed checkout;
- `ARP_CONFIRM_M8_DATASET_RESET=yes`;
- `SYNTHETIC_APPLICANT_PASSWORD` for `m6-applicant`;
- `SYNTHETIC_REVIEWER_PASSWORD` for `m6-reviewer`.

The runner:

- replaces only the M8 synthetic workload dataset with deterministic profile S / seed
  `20260914`;
- verifies the resulting dataset manifest before requesting the W1 SSH key;
- reads the live backend/frontend release identity from the retained release-state files;
- transfers only the W1 script and bounded attachment fixture to `loadgen-01`;
- passes synthetic passwords over SSH stdin and does not persist them in workload artifacts;
- runs one VU for one full business-flow iteration with a two-minute maximum;
- exercises list/detail, create/save, submit/resubmit, reviewer queue/detail, review actions,
  and attachment upload/download;
- excludes the dynamic URL system tag so application IDs do not become k6 metric labels;
- writes a run manifest, sanitized k6 console output, and k6 summary under
  `build/workload/runs/<run-id>/`.

W1 uses thresholds only to prove harness correctness: all checks must pass and HTTP request
failures must remain zero. Do not interpret W1 latency as performance evidence. W2 owns the
representative M-dataset baseline.
