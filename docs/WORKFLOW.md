# WORKFLOW — Project Tooling and Execution Rules

Status: ACTIVE BASELINE

This document defines how project work is coordinated. It does not replace the frozen M0 product, domain, architecture, security, data, recovery, workload, or non-goal documents.

## Source-of-truth precedence

When sources disagree, use this order:

1. Current GitHub repository state on the relevant branch/commit: code, committed plans, ADRs, configuration, migrations, and tests.
2. Frozen M0 documents and later approved ADRs committed in the repository.
3. Current active milestone plan under `docs/plans/active/`.
4. GitHub pull-request and GitHub Actions results for the exact commit being evaluated.
5. Interactive tool output and chat discussion.

Chat history, model memory, Codex summaries, and verbal claims are not project state until the relevant decision or change is committed.

## Tool responsibilities

### GitHub repository

GitHub is the durable project record. It owns versioned source, plans, ADRs, migrations, pull requests, commit history, CI definitions, and retained evidence references. Determine the current project state from GitHub before relying on prior chat context.

### ChatGPT

ChatGPT coordinates work: inspect current repository state, identify the active milestone and constraints, analyze failures and root causes, decide the smallest safe change, review diffs and CI evidence, and explain decisions to the project owner.

ChatGPT may make small, targeted, reviewable repository changes directly when appropriate, especially documentation, metadata, narrowly scoped fixes, and PR/CI operations. It must not treat its own prior explanation as authoritative over repository state.

### Codex

Codex is the preferred implementation workspace for substantive multi-file application, infrastructure, automation, frontend, or refactoring work. Before implementation it must read `AGENTS.md`, `docs/PROJECT_EXECUTION.md`, this workflow document, the relevant frozen M0 documents, and the current active plan.

Codex works on a branch, preserves the requested scope, runs available verification, and leaves changes in a state that can be independently reviewed through GitHub. A Codex statement that work succeeded is not a substitute for repository diff review or CI.

### ChatGPT/Codex handoff discipline

For one substantive implementation slice, assign one implementation owner. ChatGPT and Codex must not independently edit the same branch/scope in parallel.

Preferred flow:

1. ChatGPT/repository state establishes the exact base commit, active-plan scope, acceptance criteria, and prohibited changes.
2. Codex implements the bounded multi-file slice and runs available local/workspace verification.
3. GitHub diff and exact-head CI are reviewed independently.
4. ChatGPT coordinates narrow corrections, PR/CI diagnosis, merge decision, and durable plan/handoff updates.

ChatGPT may directly perform small documentation/metadata changes, PR/CI operations, or narrowly scoped fixes. It should not create a competing implementation of the same substantive Codex slice.

See `docs/PROJECT_EXECUTION.md` for the durable project-purpose and evidence guardrails.

### GitHub Actions

GitHub Actions is the authoritative automated verification path when a repository workflow covers the change. Local or Codex test results are useful early signals; required CI must pass for the exact final PR head before merge.

Do not fix CI by deleting, disabling, or weakening a valid failing test. For a failure, identify the first meaningful root cause, compare it with the exact code/configuration at that commit, and change only what is directly required before rerunning CI.

#### CI failure diagnostics

The project owner is not responsible for manually extracting GitHub Actions logs during the normal workflow. Use this order when CI fails:

1. Lock the exact PR head SHA and identify the workflow run and first failed job for that commit.
2. Retrieve the failed job's raw log directly through the GitHub integration and identify the first meaningful causal failure rather than the final job summary.
3. Compare that failure with the code and configuration at the same SHA before changing anything.
4. If the raw job log is unavailable, oversized, or unreliable through the integration, use the workflow's failure step summary and retained diagnostic artifact. Verification commands should preserve their exit status while teeing useful output to a diagnostic log, and test reports should be retained on failure.
5. Make the smallest directly supported fix and rerun CI for the new exact head.
6. Ask the project owner to paste a log excerpt only as an exceptional fallback when the GitHub integration/API cannot provide the raw log, failure summary, or diagnostic artifact.

Failure diagnostics must not print or retain secrets. Diagnostic artifacts are troubleshooting evidence, not substitutes for a passing final PR head.

### Web and external documentation

Use current upstream documentation or web research when framework, library, cloud, or tool behavior cannot be established reliably from the repository. External information may inform a decision, but a lasting project decision must be represented in repository code, documentation, or an ADR as appropriate.

### GCP and `ops-01`

From the milestone where they are introduced, GCP and `ops-01` are execution and operations environments. They produce deployment, measurement, failure, backup, and recovery evidence; they are not the design source of truth. Infrastructure and configuration that must be reproducible belong in the repository.

## Standard change flow

1. Read `AGENTS.md`, `README.md`, this document, and the M0 documents relevant to the task.
2. Confirm the current `main`, active milestone, open PRs, and CI state before changing anything.
3. For work that meets the planning threshold in `AGENTS.md`, create an active plan before implementation.
4. Create a branch from the current intended base. Do not continue an obsolete branch by assumption.
5. Implement only the active plan. Do not pull later-milestone features forward.
6. Run the most relevant available tests/checks during implementation.
7. Open or update a PR and inspect the actual diff.
8. Require GitHub Actions to pass for the final PR head when applicable.
9. If CI fails, follow the CI failure diagnostics procedure above and fix the first causal failure rather than changing multiple plausible causes at once.
10. Review the result against the milestone requirements and frozen architecture.
11. Move the active plan to `docs/plans/completed/` only when its done conditions are met.
12. Re-run CI on the resulting final head, then merge. Verify the post-merge `main` workflow when the repository runs one.

## Scope and architecture control

- The current milestone controls implementation scope.
- `AGENTS.md` controls planning, ADR, secret-handling, and definition-of-done rules.
- Frozen M0 documents control architectural boundaries unless an approved ADR explicitly changes one.
- Do not redesign a completed milestone merely because a later implementation could be cleaner.
- Prefer the smallest change that satisfies the current requirement and can be explained and verified.

## Handoff rule

A new ChatGPT or Codex session should be able to resume work from the repository without a long chat transcript. At minimum it should recover:

- what the project is trying to prove;
- the frozen architecture and non-goals;
- the latest completed milestone;
- the current active plan, if any;
- the exact branch/PR/CI state;
- the verification required before the next merge.

If those facts cannot be recovered from the repository, repair the repository documentation or project state before proceeding with substantive implementation.
