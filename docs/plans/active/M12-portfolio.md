# M12 Portfolio — Execution Plan

Status: ACTIVE
Planning base: `96c6d5008dfac5d59853b9a4e12216de374a0706`

## Goal

Convert the completed M1–M11 project into a concise, evidence-backed portfolio that can be
explained in an interview without turning the repository into a technology checklist.

M12 does not add new technical depth for résumé breadth. It selects, compresses, and presents
the strongest existing evidence.

M12 is successful when the repository can answer:

> What are the 2–3 strongest problems this project actually solved, what evidence proves each
> result, what trade-offs remain, and how should the project be presented to a reviewer who
> has only a few minutes?

## Frozen inputs

M12 starts from the completed M1–M11 repository state.

Primary candidate evidence:

- M6 immutable release + schema-compatible rollback — E5;
- M9 PostgreSQL query bottleneck and same-condition remeasurement — currently E4;
- M10 Garage fixed-endpoint failure and failover revalidation — E5;
- M11 disaster recovery correctness — E5.

Supporting evidence may include:

- optimistic-lock reviewer claim correctness;
- attachment DB/object consistency;
- M7 observability as evidence infrastructure;
- M5 browser/API product surface.

Supporting evidence does not automatically become a primary story.

## Constraints

- select only 2–3 primary stories;
- do not add a technology merely to fill a perceived résumé gap;
- do not rerun completed workload, fault, rollback, PITR, or full-DR experiments unless a
  retained claim is actually unsupported;
- do not invent production scale, SLA/SLO, availability, traffic, RTO, or RPO claims;
- keep synthetic-data wording explicit;
- preserve measured caveats, including M9 transport uncertainty and M11 unmeasured full-DR
  RTO/effective RPO;
- describe the project as a final designed/verified system, not as a chronological
  modernization diary;
- technology names are mechanisms; the primary narrative is problem → evidence → decision →
  verification → trade-off;
- prefer material already independently retained in GitHub/runtime evidence over new prose-only
  claims.

## Selection criteria

Each primary candidate must be reviewed against the same questions.

### 1. Problem clarity

Can a reviewer understand the operational/business risk without first understanding the entire
stack?

### 2. Causal evidence

Does the retained evidence distinguish the actual cause from a plausible hypothesis?

### 3. Decision quality

Was a smaller option considered before a larger architecture change? Is the chosen intervention
proportional to the evidence?

### 4. Verification strength

Was the change or recovery verified under the same/equivalent condition, or with explicit
invariants where same-condition comparison is not applicable?

### 5. Interview explainability

Can the owner explain the sequence, key commands/metrics, failure boundary, and trade-off without
memorizing a tool list?

### 6. Distinctiveness

Does the story demonstrate a different competency from the other selected stories rather than
repeating another availability/recovery narrative?

### 7. Claim safety

Can the story be stated factually without production-scale implication or unsupported numbers?

Do not turn this review into arbitrary numeric scoring. Record evidence-based selection reasons
and overlap/trade-offs instead.

## Phase 1 — candidate normalization and final story selection

Status: COMPLETE

Required work:

1. review M6/M9/M10/M11 evidence cards against the criteria above;
2. verify whether M9 already satisfies the repository E5 definition in substance;
3. if M9 qualifies, update only its maturity label/claim framing; do not create new measurements;
4. identify overlap:
   - M6: controlled delivery/reversibility;
   - M9: measured SQL/performance diagnosis and bounded optimization;
   - M10: fault isolation and minimum availability fix;
   - M11: backup/recovery and cross-store business correctness;
5. select 2–3 primary stories and record why the other strong candidates remain supporting;
6. update `docs/portfolio/PORTFOLIO_EVIDENCE_MAP.md` with the final selection.

Expected output:

- `docs/portfolio/M12_STORY_SELECTION.md`;
- Evidence Map final primary/supporting decision;
- M9 card maturity correction only if the retained evidence supports it.

No résumé bullets are written before this selection is committed.

## Phase 2 — portfolio master narrative

Status: COMPLETE

Create one reviewer-facing project narrative that explains the final system, not the milestone
history.

Required sections:

- project problem and user workflow;
- final architecture and why it is intentionally a modular monolith on GCP IaaS;
- data/security/integrity boundaries;
- selected 2–3 problem-solving stories;
- verification/evidence model;
- known limits and non-goals;
- concise technology summary after the problem/evidence narrative.

The final narrative must be understandable without reading M1–M11 plans.

Expected output:

- `docs/portfolio/PROJECT_PORTFOLIO.md`;
- README portfolio-facing refinement only where it improves repository entry clarity.

## Phase 3 — interview and application compression

Status: COMPLETE

For each selected primary story, retain three levels of explanation:

1. one-line résumé/project bullet;
2. 60–90 second interview explanation;
3. deeper technical follow-up notes covering:
   - baseline;
   - causal evidence;
   - alternatives;
   - selected action;
   - verification;
   - limitations;
   - likely interviewer follow-up questions.

Also retain one concise overall project introduction suitable for infrastructure/operations or
IT-systems roles without overstating production experience.

Expected output:

- `docs/portfolio/INTERVIEW_PACKET.md`.

Do not create company-specific self-introduction answers inside the repository.

## Phase 4 — visual/repository presentation

Status: ACTIVE

Review whether the public repository can be understood in a few minutes.

Required checks:

- README current-status section is concise and current;
- final architecture is visible and consistent with the implemented system;
- portfolio/evidence links are easy to find;
- screenshots/diagrams, if used, explain system/evidence rather than decorate the README;
- no stale active milestone references remain;
- no sensitive runtime details are exposed;
- no obsolete "planned" wording contradicts completed state.

Any visual artifact must represent the final system and verified outcomes rather than a
technology collage.

## Phase 5 — final runtime lifecycle and repository closeout

Status: PENDING

The persistent Seoul runtime must not remain running indefinitely without a portfolio reason.

Before any teardown decision:

1. confirm whether a live demo is actually required for the final portfolio;
2. if a demo is not required, retain all necessary sanitized evidence first;
3. review the OpenTofu destroy plan before apply;
4. destroy only after the portfolio evidence no longer depends on live access;
5. preserve repository/IaC reproducibility and evidence;
6. update README/AI state with the final runtime lifecycle;
7. move this plan to `docs/plans/completed/M12-portfolio.md`;
8. require exact-head and post-merge main CI success for repository closeout.

If a live demo is intentionally retained, document the reason and cost/lifecycle boundary
instead of treating indefinite runtime as the default.

## Definition of done

M12 is complete when:

- 2–3 primary stories are explicitly selected;
- no selected claim exceeds retained evidence;
- the project has one final-system portfolio narrative;
- selected stories have résumé/interview compression;
- README/public repository entry path is coherent;
- final runtime retention/destruction decision is explicit;
- the Evidence Map reflects final primary/supporting roles;
- no new résumé-driven architecture was added;
- active plan is moved to completed;
- exact-head and post-merge main CI pass.

## Phase 1 result

Final primary stories:

1. M9 PostgreSQL query bottleneck — E5;
2. M10 Garage fixed-endpoint reliability — E5;
3. M11 disaster recovery correctness — E5.

M6 immutable release/rollback remains a high-value supporting story.

Selection evidence:

`docs/portfolio/M12_STORY_SELECTION.md`

M9 was promoted from E4 to E5 without a new experiment because its retained M9 section already
contains the complete E5 chain: observed problem, SQL/plan analysis, rejected alternative,
bounded intervention, same-condition W2/W3 remeasurement, and retained trade-offs.

## Phase 2 result

Final-system narrative:

`docs/portfolio/PROJECT_PORTFOLIO.md`

The document presents the project as one implemented system:

- support-program workflow first;
- final architecture and intentional modular-monolith boundary;
- data/security/integrity boundaries;
- M9/M10/M11 as the three primary cases;
- M6 as supporting release/change-control evidence;
- explicit non-goals and claim limits;
- technology summary only after the evidence narrative.

README now provides a short portfolio entry path rather than relying on milestone history.

## Phase 3 result

Interview/application packet:

`docs/portfolio/INTERVIEW_PACKET.md`

It retains:

- 30-second and 60-second overall project introductions;
- one-line résumé/project bullets for M9/M10/M11 plus supporting M6;
- 60–90 second Korean spoken explanations;
- likely technical follow-up questions and evidence-bounded answers;
- job-family usage guidance;
- wording that must be avoided because it exceeds retained evidence.

## Immediate next work

Execute **Phase 4 — visual/repository presentation**.

Review the public repository as a first-time reviewer would:

1. README should expose the final project and three primary cases quickly;
2. architecture representation must match the final system, including the app-local Garage proxy;
3. portfolio/evidence entry links must be easy to reach;
4. stale M12/M9/M11 wording must not contradict current state;
5. visuals should be added only if they improve understanding of architecture or evidence;
6. do not create a technology-logo collage or milestone timeline as the primary presentation.

Prefer a small number of durable visual/repository improvements rather than decorative work.
