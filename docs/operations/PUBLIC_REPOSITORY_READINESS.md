# Public Repository Readiness

Status: COMPLETE  
Date: 2026-09-13

## Why the repository is being made public

The private repository exhausted the GitHub Free included Actions allowance
(2,000 / 2,000 minutes for the current billing period).

The project is intended to become a portfolio repository, and the existing CI is already
built around standard GitHub-hosted `ubuntu-latest` runners. Making the repository public
therefore avoids an unrelated CI-platform migration while keeping the established
verification boundary.

Do not replace GitHub Actions with Jenkins, Cloud Build, or a self-hosted runner merely to
work around the private-repository minute limit unless public-readiness fails for a real
security reason.

## Current repository state

- repository visibility: **public**;
- default branch: `main`;
- repository ruleset: `protect-main`, active;
- default branch deletion and non-fast-forward/force-push are blocked;
- changes require a pull request;
- strict required status checks are enabled;
- M7 Phase 1 PR #58 is merged;
- post-merge E2E locator correction PR #59 is merged.

## Secret scan finding

The first full public-readiness scan fetched branch/tag/PR refs and scanned both Git
history and the current tree.

Initial result:

- history findings: 4;
- current-tree findings: 4;
- all findings used rule `generic-api-key`;
- all four pointed to
  `app/src/test/java/com/siameselang/arp/api/M5AuthProgramApiIntegrationTest.java`;
- all four values were the literal synthetic fixture password
  `synthetic-pass-123`.

Review confirmed these are deterministic integration-test inputs, not live or historical
credentials.

No credential rotation or Git history rewrite is required for those findings.

## Gitleaks policy

Repository file:

`.gitleaks.toml`

The repository extends the default Gitleaks rule set and contains one intentionally narrow
allowlist:

- target rule: `generic-api-key`;
- exact test file only;
- exact synthetic password line pattern only.

Do not allowlist the whole test directory or disable `generic-api-key` globally.

Reproducible scanner:

`scripts/security/public-readiness-secret-scan.sh`

The scanner uses Gitleaks `v8.29.1`, redacts finding content, and checks Git history
without scanning local untracked build/cache directories.

The final history scan completed with:

```text
scan exit code: 0
findings: 0
```

Current tracked files were reviewed separately and no real secret/private-key material was
identified.

## Current-tree inspection

Repository search found no current tracked occurrences of:

- age private-key marker strings;
- private-key PEM/OpenSSH headers;
- real `db_app_password` values;
- real Garage RPC/app secret values;
- real synthetic-user runtime passwords;
- committed GitHub tokens.

Tracked secret-related files are schemas/examples/scripts only:

- `config/secrets/.sops.yaml.example`;
- `config/secrets/runtime.schema.yaml`;
- `deploy/prepare-secrets.sh`.

Runtime plaintext, the age private identity, OpenTofu state, generated inventory, and
decrypted SOPS material remain outside Git or ignored.

## Completed public-readiness audit

Secret-history gate:

- Gitleaks v8.29.1 rerun from the PR #58 branch: 0 findings;
- the earlier four generic-api-key findings were the fixed synthetic test password
  `synthetic-pass-123` in one integration-test file;
- the allowlist is restricted to that rule, file, and literal test pattern.

Actions/log/artifact gate:

- all six M6 exact-release handoff runs were reviewed;
- GitHub/GHCR token values were masked as `***`;
- Google WIF logs exposed only temporary credential-file paths, not credential contents;
- no DB/Garage/SOPS/age runtime secret was found in the reviewed deployment logs;
- retained release artifacts contain build outputs, manifests, checksums, and publication
  metadata rather than target-host runtime secret files;
- production runtime credentials remain injected on the target VM through the Ansible
  environment-file path and are not part of the release bundle.

No credential rotation or Git history rewrite is required by this audit.

## Public-transition gates

All public-transition gates are complete:

1. **PASS** — final Gitleaks history scan: zero non-allowlisted findings;
2. **PASS** — current tracked secret/private-key search clean;
3. **PASS** — deployment workflow/fork trust boundary reviewed;
4. **PASS** — historical Actions logs/artifacts reviewed with no runtime-secret exposure;
5. **PASS** — repository visibility changed to public;
6. **PASS** — `protect-main` ruleset created and active;
7. **PASS** — PR #58 exact-head CI `34752303087`;
8. **PASS** — PR #58 merged as `dfeb5cab85698812294878bcf3a154d5d628967b`;
9. **PASS** — post-merge E2E locator regression isolated and corrected by PR #59;
10. **PASS** — PR #59 exact-head CI `34752944074`;
11. **PASS** — final post-merge `main` CI `34753065713`.

## Deployment identity boundary after publication

Publishing the source repository does not authorize public contributors to deploy.

The M6 exact-release handoff remains constrained by:

- exact repository identity;
- immutable repository and owner IDs;
- `refs/heads/main`;
- exact deployment workflow reference;
- `workflow_dispatch`;
- GitHub OIDC / GCP Workload Identity Federation;
- dedicated deployment service account;
- IAP/OS Login boundary;
- no service-account JSON key.

These controls must be rechecked after visibility changes, not redesigned merely because
the source becomes public.

## Main protection after publication

The active `protect-main` ruleset targets the default branch and currently enforces:

- pull requests before merge;
- zero required approvals for this single-maintainer repository;
- strict required status checks;
- branch deletion prevention;
- non-fast-forward/force-push prevention.

The required checks cover repository/application/infrastructure/frontend/browser/Nginx
and M6/M7 delivery/static contracts. Push-only release scope/publication jobs are not PR
merge requirements.

## Remaining work

The public-transition work is closed.

Project execution resumes from M7 Phase 2 in
`docs/plans/active/M7-observability.md`. This document remains the durable record of why
the repository became public and which security/CI gates were verified.
