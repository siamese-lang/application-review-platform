# M6 Phase 6 — Closeout evidence

Status: COMPLETE  
Date: 2026-09-13

## Scope

Phase 6 closed M6 after the immutable-release/rollback drill. It did not add observability,
workload, performance, fault-injection, backup, or DR implementation.

The closeout covered:

- bounded manual inspection of the deployed HTTPS SPA;
- usability defects discovered during that inspection and their regression coverage;
- publication and activation of the final reviewed UI release;
- final HTTPS/API/Garage smoke;
- owner-bootstrap and runtime OpenTofu no-drift verification;
- an explicit runtime lifecycle disposition;
- portfolio evidence maturity review.

## Manual browser validation and bounded remediation

Manual inspection covered public, applicant, reviewer, and administrator surfaces.

Three concrete usability findings were resolved:

1. role switching could preserve an incompatible protected route after login;
   - fixed by role-aware post-login redirect handling in PR #51;
2. the browser surface was predominantly English and obscured the Korean support-program
   business context;
   - fixed by the bounded Korean public-service usability slice in PR #54;
   - the UI is KRDS-informed only; the project does not claim formal KRDS conformance;
3. disabled admin pagination buttons used a wait cursor, making a normal disabled state
   look like a loading failure;
   - fixed in PR #55;
   - focused coverage now proves admin application pagination moves to `page=1` and
     returns to `page=0`.

The pagination investigation also confirmed that admin application/user/program lists
use server-side pages of 20 items and the audit list uses pages of 50 items. The backend
uses Spring Data `PageRequest`; the buttons are disabled only when the server-reported
page bounds say no previous/next page exists.

## Final reviewed release

Final M6 closeout release:

- source SHA: `9d5fda9871e479e05dc4641fccf7dea3145d2ad6`;
- OCI digest:
  `sha256:13c3d117eef036c6987f00faf44e01b86845528c62bab1a3ea0914a234a103d4`;
- post-merge baseline/release publication run: `34737855198` — SUCCESS;
- exact-release handoff run: `34746439784` — SUCCESS.

The handoff verified the requested main SHA/digest, used the existing WIF/IAP/OS Login
boundary, and staged the verified release on `ops-01` only before explicit activation.

After activation, both release-state files reported:

- current: `9d5fda9871e479e05dc4641fccf7dea3145d2ad6`;
- previous: `60a7efe40dd7f3d6f0c0f10396246c4da4148cc4`.

The final deployed HTTPS/API/Garage smoke passed, including applicant workflow,
attachment SHA-256 integrity, reviewer workflow, and final application history.

No additional rollback drill was performed for this UI-only closeout release. The real
schema-compatible rollback mechanism was already exercised and retained in Phase 5.

## Final infrastructure no-drift verification

The controlled runtime root on `ops-01` was planned with the actual project ID and the
retained `storage-03` capacity overrides:

- `storage-03` machine type: `e2-small`;
- `storage-03` boot disk type: `pd-standard`.

Result:

`No changes. Your infrastructure matches the configuration.`

OpenTofu detailed exit code: `0`.

The retained owner-bootstrap root was also planned from the controlled Cloud Shell state.

Result:

`No changes. Your infrastructure matches the configuration.`

No plan was applied because no changes were required.

A discarded intermediate runtime plan used an incorrect interactive `project_id=yes`
input and omitted the retained `storage-03` overrides. It was correctly treated as an
invalid invocation and was never applied.

## Runtime lifecycle disposition

Decision: **retain the seven-role runtime for immediate M7 Observability work**.

Reason:

- M7 requires telemetry from the existing edge/app/db/storage runtime into the planned
  observability boundary;
- destroying the seven-role runtime now would require recreating and reconfiguring the
  same verified substrate immediately before M7;
- retaining it avoids unnecessary reconstruction while the project is actively
  continuing.

This is not an indefinite-retention decision. M7 closeout must re-evaluate retain versus
destroy based on the next immediate milestone and remaining GCP trial/credit cost.

## Evidence maturity decision

The M6 immutable-release/rollback candidate is promoted from E3 to **E5**.

The promotion is based on retained evidence for:

- an observed pre-M6 identity/reversibility gap;
- analysis that rejected unrelated stack expansion;
- a bounded immutable paired-release design;
- exact SHA/digest/checksum verification;
- a real schema-compatible B → A rollback;
- full business/attachment revalidation after rollback;
- restoration to the intended release;
- explicit database rollback limits and trade-offs;
- final manual/runtime/no-drift/lifecycle closeout controls.

The 38.346-second rollback observation remains one measured drill result, not an SLA.

## Related evidence

- `docs/operations/M6_PHASE4_RUNTIME_EVIDENCE.md`
- `docs/operations/M6_PHASE5_RELEASE_ROLLBACK_EVIDENCE.md`
- `docs/portfolio/M6_IMMUTABLE_RELEASE_ROLLBACK_EVIDENCE.md`
- `docs/portfolio/PORTFOLIO_EVIDENCE_MAP.md`
