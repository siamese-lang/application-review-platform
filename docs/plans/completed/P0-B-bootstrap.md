# P0-B Repository Bootstrap

## Goal

Turn the frozen M0 design from chat-only context into repository source of truth and prove the branch → PR → CI → merge development loop.

## Files / components

M0 documentation, `AGENTS.md`, repository skeleton, baseline verification script, and GitHub Actions workflow.

## Constraints

No business implementation, GCP resource, secret, dependency, or architecture change is introduced in this bootstrap.

## Verification

The CI workflow runs `scripts/verify-repo-baseline.sh` on pull requests and pushes to `main`. It verifies that required M0 documents and repository skeleton paths exist and that frozen markers/core architecture terms have not been accidentally omitted.
