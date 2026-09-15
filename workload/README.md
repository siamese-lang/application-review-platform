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
- reads the live backend/frontend release identities from the retained release-state files;
- records the backend SHA as the API workload `release_sha` and preserves both component
  SHAs under `runtime.component_releases`;
- does not require backend/frontend component SHAs to be equal, because the retained runtime
  may contain an independently updated backend while the API workload still needs the exact
  component identities recorded;
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


## W2 mixed normal baseline

`k6/w2-baseline.js` is the primary M8 normal-load measurement harness.

The repository-owned entrypoint is:

```bash
bash workload/run-w2.sh
```

The operator environment uses the same exact-source and controlled synthetic credential
boundary as W1.

Before measurement the runner:

- restores deterministic dataset M / seed `20260914`;
- applies `sql/w2-interactive-overlay.sql`, which reassigns only generated history-free
  DRAFT applications to the controlled `m6-applicant` identity and aligns their create
  audit actor;
- verifies `pg_stat_statements` is active and resets its cumulative counters;
- records the exact dataset manifest and overlay SHA-256 values.

W2 runs 30 VUs for 15 minutes with six concurrent constant-VU scenarios. Scenario pacing
targets the frozen business-request mix:

- list/detail: 12 req/s (40%);
- create/save: 4.5 req/s (15%);
- submit: 3 req/s (10%);
- reviewer queue/detail: 6 req/s (20%);
- review actions: 3 req/s (10%);
- attachment upload/download: 1.5 req/s (5%).

Authentication, CSRF acquisition, and attachment cleanup are tagged as support traffic and
are excluded from the business-mix counters. They still traverse the real deployed boundary
and therefore remain part of system load.

The runner retains:

- k6 console output and JSON summary;
- exact run manifest, including backend/frontend component releases;
- observed business-request mix;
- non-file success rate and p95 compared with the project-internal regression target;
- top 20 `arp_app` query families from `pg_stat_statements`.

A regression-target miss is retained as measurement evidence; the runner does not tune the
system or rerun automatically to obtain a better number.


## W3 bounded peak baseline

`k6/w3-peak.js` is the M8 bounded-peak profile after the closed-VU diagnostic showed that
scenario throughput diverges under saturation.

The repository-owned entrypoint remains:

```bash
bash workload/run-w3.sh
```

W3 restores deterministic dataset M / seed `20260914`, applies the same interactive
DRAFT ownership overlay, resets `pg_stat_statements`, and retains the same evidence classes
as W2.

The retained W3 profile uses six independent `constant-arrival-rate` scenarios so the
**offered** business mix does not collapse when one family becomes slower:

- list/detail: 20 iterations/s = 40 business requests/s;
- create/save: 15 iterations / 2 s = 15 business requests/s;
- submit/resubmit: 10 iterations/s = 10 business requests/s;
- reviewer queue/detail: 10 iterations/s = 20 business requests/s;
- review actions: 5 iterations/s = 10 business requests/s;
- attachment upload/download: 5 iterations / 2 s = 5 business requests/s.

The nominal offered business rate is therefore 100 requests/s with the frozen
40/15/10/20/10/5 mix.

Scenario VU pools retain the previous 40/14/10/20/10/6 allocation. Both preallocated and
maximum VUs sum to 100. k6 therefore records `dropped_iterations` when the system cannot
sustain the offered rate instead of silently changing the workload mix by slowing individual
closed-VU loops.

The run remains bounded to 10 minutes. The mutable deterministic pools stay within dataset-M
limits at the configured arrival rates:

- submit: at most 6,000 started iterations against a 7,000-DRAFT pool;
- review actions: at most 3,000 started iterations against a 3,500-SUBMITTED pool.

Support CSRF/login/cleanup traffic still uses the real deployed boundary. Support failures
are measured separately and do not globally abort the entire peak run.

W3 is measurement, not optimization. A target miss, support failure, or dropped iteration is
retained as evidence rather than tuned away or automatically rerun.
