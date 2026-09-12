# M6 Operations & Delivery — Execution Plan

Status: ACTIVE

## Goal

Turn the completed M5 application into a controlled, reproducible release and deployment flow without changing the frozen runtime architecture.

M6 must prove that one reviewed repository revision can be:

1. built into identifiable backend and frontend release artifacts;
2. retained outside a developer workstation;
3. deployed to the existing GCP IaaS topology through the controlled operations path;
4. verified over the real HTTPS edge;
5. rolled back to a known previous release when the database schema remains backward compatible.

M6 is about **delivery and operational release control**, not observability, workload, performance, failure injection, backup implementation, or DR.


## Portfolio evidence objective

M6 is not a portfolio story about “using GHCR, WIF, Ansible, and symlinks.”

Its primary problem-solving candidate is:

> The previous deployment path could not prove that backend and frontend came from one immutable reviewed revision or that a known compatible release could be restored exactly.

M6 may promote this candidate only with retained evidence.

Required evidence for promotion:

- exact source commit SHA and OCI digest;
- backend/frontend payload checksums bound by one release manifest;
- active release identity before deployment;
- active release identity after deployment;
- actual schema-compatible rollback to a retained previous release;
- public/API/business smoke after rollback;
- elapsed rollback operation time as an observation, not a promised SLA;
- final return to the intended release;
- explicit statement that database migrations are not automatically rolled back.

GitHub OIDC/WIF, GHCR, Ansible, OpenTofu, and symlink mechanics are implementation choices supporting that claim. Do not turn each mechanism into a separate résumé bullet.

If the actual rollback drill exposes a different or more useful problem, update `docs/portfolio/PORTFOLIO_EVIDENCE_MAP.md` rather than forcing the planned narrative.

## Confirmed starting point

M5 is complete at:

- current planning base: `2ad834552ca5118f1ccd1a1f06c79a0f3cb49bd5`;
- M5 completed plan: `docs/plans/completed/M5-web-api-product-surface.md`;
- M5 post-merge `main` workflow run `34617050248`: SUCCESS;
- required M5 jobs: `repository-baseline`, `m1-application`, `m4-infrastructure-static`, `m5-frontend`, `m5-browser-e2e`, and `m5-nginx-routing`: all green.

The M4 runtime is intentionally destroyed. M6 must not assume that the old seven VMs, VPC, NAT, disks, or edge IP still exist.

The retained owner-bootstrap IAM/service-account root and repository OpenTofu/Ansible configuration are the starting infrastructure baseline.

## Existing delivery gaps

The repository already proves infrastructure provisioning and application behavior, but it does not yet provide a final delivery path.

Current gaps:

- `deploy/build-and-configure.sh` builds the JAR from the working tree and copies a local path through Ansible;
- the M5 frontend static release has no versioned release/install/rollback path on `edge-01`;
- backend and frontend are now bound by the Phase 1 release manifest and retained GHCR artifact; deployment/rollback consumption of that artifact is still pending;
- a retained artifact registry record now exists for exact reviewed revisions; Phase 2+ must consume it rather than rebuilding from a working tree;
- there is no GitHub-to-GCP keyless deployment identity;
- there is no controlled deployment workflow that accepts one explicit release revision/digest;
- rollback is not implemented as a tested operational command;
- `deploy/cloud-smoke.sh` still describes the removed Thymeleaf/form-login interface and must not be used as M6 evidence in its current form;
- current synthetic privileged-user bootstrap predates the final M5 identity fields and must be brought forward before cloud verification.

## Frozen architecture and non-goals

M6 preserves:

- React/TypeScript/Vite as a static frontend;
- Nginx as the only public service ingress and static frontend server;
- Spring Boot executable JAR under systemd on `app-01`;
- PostgreSQL as the single primary;
- Garage as the object store;
- `ops-01` as the controlled operations node;
- OpenTofu + Ansible as infrastructure/configuration source of truth;
- SOPS + age as runtime-secret handling;
- IAP + OS Login for administrative access.

M6 does **not** containerize the Spring runtime merely because GHCR is used as an artifact registry.

Do not add:

- Kubernetes;
- Cloud Run/GKE/Cloud SQL;
- a separate frontend VM;
- a Node production server;
- Redis/Kafka/queue infrastructure;
- a second object store;
- automatic PostgreSQL failover;
- observability stack implementation;
- load generation;
- performance indexes;
- backup/PITR implementation;
- reliability/DR experiments.

No ADR is required for the M6 baseline because GHCR, GitHub Actions, SOPS + age, OpenTofu, Ansible, and the VM topology are already part of the accepted architecture. Any change to those frozen boundaries requires a separate ADR before implementation.

## Release identity and artifact contract

M6 will use **one immutable release identity per full Git commit SHA**.

A release contains:

- executable Spring Boot JAR;
- compressed Vite `frontend/dist` release;
- machine-readable release manifest;
- SHA-256 checksum for each payload;
- full source commit SHA;
- artifact filenames and sizes;
- release-format version.

The release manifest must not contain secrets.

The backend and frontend must always be promoted as one logical release revision even though they remain separate runtime artifacts.

### Artifact registry

Use GHCR as the retained artifact registry because it is already in the planned technology baseline.

Use GHCR as an **OCI artifact store**, not as a reason to change the runtime to containers.

Target model:

- repository/package: a dedicated ARP release artifact package;
- immutable tag keyed by full Git commit SHA;
- deployment resolves and records the OCI digest;
- rollback/deploy commands use the exact commit/digest, never a floating `latest` tag.

Use a pinned ORAS client/version with verified checksum or a pinned trusted setup action. Do not curl an unpinned binary.

### Publication boundary

Artifact publication occurs only for a reviewed `main` revision after the existing required CI jobs are green.

PR validation may build the bundle and verify its manifest/checksums but must not publish a release artifact.

A main release-publish job may be added after the current baseline jobs and should use only narrowly scoped `packages: write` permission.

No GCP mutation occurs merely because `main` changes.

## Deployment trigger and safety model

Real cloud deployment is **explicit only**.

Use a separate `workflow_dispatch` deployment workflow or equivalent explicit operator action.

The deployment input must identify an exact release commit/digest.

Do not automatically deploy every `main` push to GCP.

Required deployment safety properties:

- one deployment at a time through workflow concurrency control;
- explicit target release identity;
- reject artifact/source-manifest mismatch;
- no deployment from an unreviewed branch artifact;
- no static GCP service-account JSON key;
- no runtime application secrets passed through command-line output or committed files;
- failure must stop before advancing the frontend/backend release pointer when possible.

## GitHub → GCP identity

M6 will prefer GitHub OIDC / GCP Workload Identity Federation for cloud deployment authentication.

Extend the retained owner-bootstrap IAM configuration rather than creating an unmanaged credential manually.

The trust must be restricted to this repository and intended branch/workflow context.

The GitHub deployment job may impersonate the existing operations service account only with the minimum roles needed for the controlled operations path.

Do not commit or store a downloadable GCP service-account private key in GitHub Secrets.

The deployment job may receive `id-token: write` only where OIDC is required.

## Controlled operations path

The deployment workflow should use GitHub only to authenticate, resolve/download the exact release, and reach `ops-01` through the supported IAP/OS Login path.

Runtime secret decryption stays on the controlled operations path.

The GitHub runner must not receive the SOPS age private key or decrypted DB/Garage/application passwords.

Expected flow:

```text
reviewed main SHA
  ↓
GHCR OCI release (JAR + frontend + manifest)
  ↓ explicit workflow_dispatch
GitHub OIDC → GCP operations identity
  ↓ IAP / OS Login
ops-01
  ↓ private administrative path
app-01 + edge-01
```

Exact transport commands may change during implementation if the existing OS Login wrapper provides a safer/simpler equivalent, but the trust boundary above must remain.

## Runtime secret readiness

M6 must verify the SOPS/age path before real cloud deployment.

If the previous M4 age private key was not intentionally retained outside Git, do **not** attempt to reconstruct it.

Instead:

1. create a new age key in the controlled operations path;
2. retain the private key outside Git with restrictive permissions;
3. record only the public recipient where repository configuration requires it;
4. generate fresh synthetic runtime secrets;
5. create/refresh the committed SOPS-encrypted runtime file through `deploy/prepare-secrets.sh`;
6. securely delete plaintext staging material.

Because the M4 runtime was destroyed, rotating these synthetic runtime credentials is acceptable and preferred over trying to recover obsolete values.

No secret values belong in plan text, prompts, CI logs, evidence documents, screenshots, or frontend build variables.

## Versioned install layout

### Backend

Preserve the systemd/JAR runtime.

Use versioned backend files under `/opt/arp/releases/` and keep `/opt/arp/application.jar` as the active symlink.

The install path must verify the artifact checksum before switching the symlink.

### Frontend

Introduce a versioned static release layout, for example:

```text
/opt/arp/frontend/releases/<full-sha>/
/opt/arp/frontend/current -> releases/<full-sha>
```

Nginx continues to serve `/opt/arp/frontend/current`.

The release extraction must prevent path traversal and must not write outside the intended release directory.

Keep at least the immediately previous verified release until rollback verification is complete.

Artifact-retention cleanup is allowed only after the active/previous release identities are known.

## Deployment and migration order

The database is not automatically rolled back.

M6 keeps the existing Flyway-only schema policy.

For a release with compatible/additive migrations, deploy in this order:

1. resolve exact OCI digest and verify release manifest/checksums;
2. stage backend and frontend files without changing active symlinks;
3. record the currently active backend/frontend release identities;
4. switch/restart the backend first;
5. allow Flyway to apply required migrations during backend startup;
6. poll a real API readiness endpoint/path with bounded timeout;
7. run a minimal API/business sanity check;
8. switch the frontend symlink;
9. validate Nginx and reload only if required;
10. verify public HTTPS SPA routing and API proxying;
11. record the deployed commit/digest and previous release.

Reason for backend-first ordering:

- the previous frontend must remain compatible during the short backend upgrade window;
- the new frontend must not become active before the API version it expects is ready.

Any future release containing a migration that is not backward compatible with the previous application binary must declare that rollback is blocked and requires forward repair. M6 must never pretend that reverting a JAR reverses a database migration.

## Rollback contract

Implement an explicit rollback command/workflow step that targets a known retained release.

For schema-compatible releases:

1. identify current and target release;
2. validate the target release files/checksums;
3. switch frontend back to the target release;
4. switch backend symlink back to the target JAR;
5. restart backend;
6. verify API readiness;
7. verify SPA/API routing;
8. record rollback result.

No Flyway `undo` or destructive down-migration is introduced.

Rollback must fail closed if the target artifact is missing, checksum verification fails, or the operator has not acknowledged a known schema-compatibility restriction.

## Synthetic privileged-account bootstrap

Bring `deploy/bootstrap-synthetic-users.sh` forward to the final M5 user schema.

It must provision synthetic REVIEWER/ADMIN accounts with the fields required by the final application contract without creating any public privileged-registration endpoint.

Passwords remain generated/provided only through the controlled operations path and persisted as BCrypt hashes.

Do not use real names, organizations, email addresses, or production credentials.

## Cloud smoke after Thymeleaf removal

The current `deploy/cloud-smoke.sh` is obsolete and must be replaced or rewritten before M6 runtime evidence.

The new cloud smoke must target the final M5 boundary.

Minimum automated deployed smoke:

- HTTPS edge reachability;
- SPA root/deep-link static routing;
- public `/api/v1/programs` through Nginx;
- applicant registration/login/session/CSRF path or an equivalent real applicant API flow;
- application create/edit/submit;
- reviewer login/start/decision using controlled synthetic reviewer credentials;
- attachment upload/download integrity through the deployed Garage path;
- final application state/history check.

The smoke may execute from `ops-01` so privileged runtime credentials can remain inside the controlled SOPS-decrypted operations environment.

Do not send decrypted reviewer/admin/runtime credentials back to GitHub merely to run a browser test.

The existing CI-local Chromium E2E remains the browser-contract proof. M6 additionally proves that the real deployed HTTPS release path works.

## Manual browser validation

After the controlled cloud deployment succeeds, keep the M6 runtime available long enough for the project owner to open the real HTTPS SPA directly and inspect the implemented pages.

At minimum manually inspect:

- public program pages;
- applicant registration/login;
- applicant application/detail workflow;
- reviewer queue/detail;
- admin dashboard/program/operational pages.

This is a usability inspection, not a replacement for automated CI/E2E.

Do not build a separate temporary preview environment for this purpose.

## Cost/lifecycle rule

Do not provision GCP during repository-only M6 phases.

Re-provision the runtime only after artifact publication, install/rollback logic, identity, and static CI checks are ready.

Once real M6 verification begins:

- capture deployment/rollback evidence promptly;
- allow a bounded manual browser-validation window;
- explicitly choose whether to retain the runtime for immediate M7 work or destroy it again;
- record that choice in M6 completion evidence.

Do not silently leave seven-role infrastructure running indefinitely.

## Implementation slices

### Phase 1 — Release artifact contract and CI publication

Status: **COMPLETE**

Repository-only; no GCP runtime.

Implemented:

- deterministic release-bundle script;
- release manifest and SHA-256 verification;
- frontend static archive;
- exact backend JAR selection;
- pinned ORAS tooling;
- GHCR OCI artifact publication for green `main` only;
- CI extraction/verification plus tamper rejection;
- main-push release-scope gate so docs/README-only revisions do not publish redundant runtime artifacts.

Completion evidence:

- final Phase 1 source/main SHA: `9ad7f7215e1718ea02581ca812ceed9827163774`;
- post-merge workflow run: `34670853384`;
- required existing jobs: all SUCCESS;
- `m6-release-scope`: SUCCESS;
- `m6-release-bundle`: SUCCESS;
- `m6-release-publish`: SUCCESS;
- immutable GHCR tag: `ghcr.io/siamese-lang/application-review-platform-release:9ad7f7215e1718ea02581ca812ceed9827163774`;
- OCI digest: `sha256:e54972565b6f78015263a3ef0700b0eba09d052c82cbd545afdd9fef5bc595d7`;
- publication job pulled the artifact back by digest and re-ran the release-manifest/checksum verifier successfully;
- no GCP runtime resource was created or changed by Phase 1.

The earlier Phase 1 publication at `160051cf314843544da1c54124bf7c62e4177efb` was a successful intermediate release used to inspect the first real GHCR path. The completion record above supersedes it for subsequent M6 work.

Phase 1 remains enabling evidence. It establishes immutable release identity and retention, but it does **not** prove deployment or rollback and therefore does not by itself make the M6 portfolio story ready.

### Phase 2 — Versioned install and rollback mechanics

Repository-only/static or isolated CI where possible.

Implement:

- versioned frontend release installation;
- backend/frontend active-release metadata;
- atomic symlink switching;
- checksum verification;
- deploy/rollback scripts;
- Ansible changes required for release directories;
- regression/static tests;
- replacement of M4 build-from-working-tree assumptions in the final release path.

Do not remove useful M4 provisioning scripts unless their replacement is verified.

Done when deployment and rollback mechanics can be exercised safely without requiring a live production-like GCP environment.

### Phase 3 — Keyless delivery identity and deployment workflow

Repository/IAM definition work first; no application deployment yet.

Implement:

- GitHub OIDC/GCP Workload Identity Federation in owner-bootstrap IaC;
- repository/ref-constrained trust;
- explicit `workflow_dispatch` deployment workflow;
- concurrency guard;
- exact artifact input/digest verification;
- IAP/OS Login handoff to `ops-01`;
- no long-lived GCP service-account key.

Done when static CI is green and the workflow cannot deploy an arbitrary unreviewed artifact.

### Phase 4 — Runtime and secret preflight

Real GCP begins here.

Perform:

- current billing/API/quota readiness check;
- controlled OpenTofu plan/apply from current repository state;
- re-create the seven-role runtime;
- bootstrap `ops-01`;
- restore or rotate SOPS/age material safely;
- fresh synthetic DB/Garage/application credentials;
- Garage bootstrap;
- synthetic privileged users against the final M5 schema;
- verify no unexpected OpenTofu drift after configuration.

Do not implement M7 observability services merely because `obs-01` exists.

### Phase 5 — Exact release deployment and rollback drill

Deploy an immutable release through the new M6 path.

Verify:

- artifact digest/manifest;
- backend-first deployment order;
- Flyway state;
- API readiness;
- frontend activation;
- HTTPS SPA/API smoke;
- attachment persistence;
- active release identity.

Then deploy a second schema-compatible release or otherwise establish two retained compatible releases and perform an actual rollback drill.

Verify rollback with the same public/API checks.

Return to the intended final release after the drill.

Record the rollback observation in a draft/updated Evidence Card, including release identities, checksums/digest references, smoke result, elapsed rollback time, and migration-compatibility limit.

### Phase 6 — M6 evidence and lifecycle closeout

Record sanitized evidence:

- release source SHA;
- OCI digest;
- artifact checksums without secret values;
- deployment workflow run;
- target release before/after;
- Flyway migration state;
- HTTPS smoke result;
- rollback target/result;
- final active release;
- post-deploy infrastructure plan result;
- manual browser validation result;
- retain/destroy decision for the runtime;
- updated `docs/portfolio/PORTFOLIO_EVIDENCE_MAP.md` maturity for the M6 candidate;
- an M6 Evidence Card if the rollback candidate reaches E3 or higher.

Then:

- move this plan to `docs/plans/completed/`;
- update README;
- require final exact-head CI;
- merge;
- verify post-merge `main`.

## Expected files/components

Likely M6 work includes:

- `.github/workflows/baseline-ci.yml`;
- a dedicated deployment workflow under `.github/workflows/`;
- `scripts/deploy/`;
- existing `deploy/` scripts that need final-boundary replacement;
- `config/ansible/roles/app/`;
- `config/ansible/roles/edge/`;
- `config/ansible/roles/ops/`;
- `infra/opentofu/bootstrap/`;
- `config/secrets/`;
- M6 operational evidence/runbook documents.

File names may be refined per slice, but implementation must remain within this milestone contract.

## Verification baseline for every M6 PR

Preserve the completed M5 checks:

- `repository-baseline`;
- `m1-application`;
- `m4-infrastructure-static`;
- `m5-frontend`;
- `m5-browser-e2e`;
- `m5-nginx-routing`.

Add focused M6 verification rather than weakening existing jobs.

No M6 PR merges from a failing exact head.

## M6 completion criteria

M6 is complete only when all are true:

- backend and frontend are represented by one immutable release manifest/revision;
- a reviewed main release is retained in GHCR by exact digest;
- release payload checksums are verified before install;
- GitHub-to-GCP deployment uses keyless OIDC/WIF rather than a stored service-account key;
- cloud deployment is explicit, not automatic on every main push;
- `ops-01` remains the controlled runtime-secret/deployment boundary;
- frontend and backend install paths retain versioned releases;
- rollback has been executed successfully for a schema-compatible pair;
- database migrations are explicitly excluded from automatic rollback;
- final M5 SPA/API cloud smoke passes over HTTPS;
- attachment upload/download integrity is verified through the deployed Garage path;
- the project owner can open the actual deployed SPA for manual inspection;
- sanitized deployment/rollback evidence is committed;
- cost/lifecycle disposition is recorded;
- the M6 evidence candidate is updated honestly in the Portfolio Evidence Map, including a negative/non-distinctive result if applicable;
- final exact-head CI passes;
- post-merge `main` CI passes.

## Explicit deferrals

M7 owns observability implementation.

M8 owns representative data/workload generation.

M9 owns measured performance analysis and SQL/index tuning.

M10 owns deliberate reliability/fault experiments.

M11 owns backup/recovery/DR implementation and evidence.

M6 must not pull those milestones forward merely because a live runtime is temporarily available.
