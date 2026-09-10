# Project Workflow Governance — Execution Plan

Status: COMPLETED

## Goal

Make the repository sufficient to recover not only product and architecture intent, but also the current milestone state and the expected roles of ChatGPT, Codex, GitHub, GitHub Actions, and later GCP/ops-01 work.

## Files / components

- `README.md`
- `AGENTS.md`
- `docs/WORKFLOW.md`
- this plan file

## Constraints

- Documentation-only change; do not modify M1 application behavior or begin M2 implementation.
- Preserve the frozen M0 architecture and milestone sequence.
- Keep GitHub repository state authoritative over chat history or tool summaries.
- Define tool roles without requiring any single interactive tool to be available for every task.

## Verification

- Repository baseline CI remains green.
- Application CI remains green despite no application-code changes.
- README reports M1 complete and M2 as the next milestone.
- `AGENTS.md` requires the workflow document to be read before substantive work.
- `docs/WORKFLOW.md` defines source-of-truth precedence, tool responsibilities, branch/PR/CI flow, and failure-analysis rules.

## Done when

The documentation is internally consistent, this plan is moved to `docs/plans/completed/`, CI passes on the final PR head, and the documentation-only PR is merged before M2 work starts.
