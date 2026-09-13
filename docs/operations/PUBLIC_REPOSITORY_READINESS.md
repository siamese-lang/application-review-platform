# Public Repository Readiness

Status: READY FOR VISIBILITY SWITCH  
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

- repository visibility: private;
- default branch: `main`;
- current `main` protection flag observed through GitHub API: false;
- active implementation PR: #58;
- PR #58 current work includes M7 Phase 1 and ADR-002 resource-placement documentation;
- visibility has **not** yet been changed.

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

The scanner uses Gitleaks `v8.29.1`, redacts finding content, and checks both Git history
and the current tree.

The final public-readiness secret gate is:

```text
history scan exit code: 0
current tree exit code: 0
history findings: 0
current-tree findings: 0
PUBLIC READINESS SECRET SCAN: PASS
```

## Current-tree inspection

Repository search found no current tracked occurrences of:

- `AGE-SECRET-KEY-`;
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

The repository must not be made public until all of these are satisfied:

1. final Gitleaks history/current-tree scan passes with zero non-allowlisted findings;
2. current tracked secret/private-key search remains clean;
3. deployment workflow review confirms fork/PR code cannot obtain the trusted GCP
   deployment identity;
4. historical Actions logs/artifacts are reviewed for operational secret exposure;
5. public visibility is enabled manually in GitHub repository settings;
6. immediately after visibility change, `main` protection/ruleset is configured;
7. PR #58 exact-head CI is rerun using free public-repository standard runners;
8. PR #58 merges only when required checks are green;
9. post-merge `main` CI passes.

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

## Required main protection after publication

The private GitHub Free repository currently reports `main` as unprotected.

After the repository becomes public, configure a ruleset/branch policy that at minimum:

- requires changes through a pull request;
- prevents force pushes to `main`;
- prevents branch deletion;
- requires the baseline CI checks used by the project before merge;
- preserves administrator recovery only where necessary.

Do not mark public transition complete until this is verified.

## Remaining work

Immediate next work:

1. perform the manual repository visibility switch from private to public;
2. create/verify the `main` ruleset immediately after the switch;
3. rerun PR #58 exact-head CI;
4. merge only after all required checks pass;
5. verify post-merge `main` CI;
6. continue M7 Phase 2 only after the public transition is closed.
