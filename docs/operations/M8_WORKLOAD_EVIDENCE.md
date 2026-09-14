# M8 Workload — Live Evidence

Status: ACTIVE / W1 VERIFIED  
Last updated: 2026-09-14 UTC

This record contains sanitized M8 workload evidence. It intentionally omits passwords,
session/CSRF material, OS Login keys, decrypted SOPS content, request bodies containing
credentials, and other secret material.

## W1 — workload harness smoke

Purpose: prove workload-harness correctness through the real deployed boundary. W1 is not
performance evidence.

Verified live run:

- run ID: `m8-w1-20260914T181710Z-faf46c4c`;
- workload source SHA: `faf46c4c8256c9921a7aa6da37902b2d3dc53dbf`;
- backend/API release SHA:
  `cea4ca09d05efd89bcb9227c866d841968c08547`;
- frontend release SHA:
  `549511b0a8af9582125e89aaa2bde7fc4bffcd6d`;
- dataset: S, seed `20260914`;
- dataset manifest SHA-256:
  `b6d964b5bb482ed3ec241e2292b8e98b9d3fc19d7a3e8a2394266288f96a5191`;
- load generator: private Tokyo `loadgen-01`, k6 `2.2.0`;
- profile: 1 VU, 1 iteration, 2-minute maximum;
- observed completion: one iteration in about 5.2 seconds;
- result: PASS.

The successful business flow exercised:

- list/detail;
- create/save;
- submit and resubmit;
- reviewer queue/detail;
- review start, revision request, restart, and approval;
- attachment upload, byte-identical download, and cleanup;
- real HTTPS, session, and CSRF handling.

The 5.2-second completion time is retained only as run context. It is not a throughput,
latency, SLA, SLO, or performance claim.

Two runner defects were exposed before the successful run and corrected rather than hidden:

1. k6 attachment fixture resolution needed to be relative to the script directory;
2. the live runtime legitimately had different backend/frontend component release SHAs, so
   W1 now records both instead of imposing a false equality requirement.

## W2 — mixed normal baseline

Status: IMPLEMENTATION PENDING REVIEW / NOT YET EXECUTED.

Frozen target:

- dataset M;
- 30 VU;
- 15 minutes;
- business mix 40/15/10/20/10/5;
- real authentication/session/CSRF;
- Tokyo load generation;
- retained k6 summary and `pg_stat_statements` snapshot.

No W2 result or performance conclusion is recorded yet.
