# M6 Delivery Identity Contract

Status: PHASE 3A REPOSITORY CONTRACT

## Trust boundary

GitHub Actions exchanges an OIDC token from exactly
`https://token.actions.githubusercontent.com` through the bootstrap-managed Workload
Identity Pool provider. The provider maps `google.subject`, `repository`,
`repository_id`, `repository_owner`, `repository_owner_id`, `ref`, `workflow_ref`, and `event_name`, and accepts a token only
when all of these deployment constraints hold:

- `repository == siamese-lang/application-review-platform`;
- `repository_id == 1363362616`;
- `repository_owner == siamese-lang`;
- `repository_owner_id == 174786754`;
- `ref == refs/heads/main`;
- `workflow_ref == siamese-lang/application-review-platform/.github/workflows/deploy-release.yml@refs/heads/main`;
- `event_name == workflow_dispatch`.

The service-account impersonation member is additionally a `principalSet` selected by
the immutable repository ID attribute. The readable repository/owner names remain in
the provider condition as defense-in-depth and operator clarity, but authorization does
not depend on reusable names alone. Phase 3B will create the named workflow; its absence
in Phase 3A is intentional, so no current workflow can satisfy the complete condition.

## Dedicated identity and permissions

`arp-m6-github-deploy` is separate from `arp-m4-ops`. It has only:

- project `roles/compute.osAdminLogin` for the controlled, sudo-capable OS Login handoff;
- instance-scoped `roles/compute.viewer` on `ops-01` only, because live `gcloud compute ssh` host-key verification reads `compute.instances.getGuestAttributes`, which is not included in `roles/compute.osAdminLogin`; project-wide Compute Viewer remains intentionally forbidden;
- project `roles/iap.tunnelResourceAccessor`, conditioned on
  `destination.ip == '10.40.0.50' && destination.port == 22`;
- `roles/iam.serviceAccountUser` on the specific `arp-m4-ops` service account attached
  to `ops-01`, rather than at project scope; and
- `roles/iam.workloadIdentityUser` on the deployment service account for only the
  exact repository attribute principal set.

The deployment identity receives no project-wide Compute Viewer, Compute/network
administrator, runtime-secret, workload-service-account, or owner-bootstrap/runtime-apply
grant directly. Its only Compute Viewer grant is bound to the single `ops-01` instance
to support authenticated SSH host-key retrieval. GitHub is not federated directly to `arp-m4-ops`.

This separation limits the Google IAM permissions available before SSH, but successful
OS Admin Login to `ops-01` intentionally crosses into the privileged operations
boundary. Because that VM carries `arp-m4-ops`, a process with root-level access on
`ops-01` can obtain credentials for that attached service account from the metadata
server. The exact repository/workflow/ref/event WIF constraints and the
`10.40.0.50:22` IAP restriction are therefore security boundaries, not merely
organizational separation. Phase 3B must not turn this handoff into an arbitrary
branch-command execution path.

IAP therefore cannot be used by the deployment identity to tunnel directly to edge,
application, database, or storage nodes. The only permitted tunnel is SSH to the
fixed private address of `ops-01`, `10.40.0.50:22`.

## Keyless setup outputs

The bootstrap outputs are nonsensitive identifiers, not proof that repository
settings have been configured:

- `github_workload_identity_provider` maps to the future GitHub repository variable
  `GCP_WORKLOAD_IDENTITY_PROVIDER`;
- `github_deployment_service_account_email` maps to the future repository variable
  `GCP_DEPLOY_SERVICE_ACCOUNT`;
- `github_workload_identity_pool_name` supports operator inspection.

No service-account private key or JSON credential is created, stored, or output.
Phase 3A performs no GCP apply or runtime mutation. Phase 3B will consume this identity
contract for explicit exact-release validation, WIF authentication, and the IAP/OS
Login handoff; it remains separately scoped work.

## Phase 3B exact-release handoff

The manually dispatched `.github/workflows/deploy-release.yml` requires a lowercase
40-character `release_sha` and a lowercase `sha256:` `release_digest`. It guards the
repository, main ref, and event; proves the commit is reachable from `origin/main`;
resolves the fixed full-SHA GHCR tag; requires its digest to equal the operator input;
checks OCI source/revision annotations; pulls by digest; and runs the existing bundle
verifier. Only then does it check the two repository variables, exchange GitHub OIDC
through `GCP_WORKLOAD_IDENTITY_PROVIDER` as `GCP_DEPLOY_SERVICE_ACCOUNT`, and use IAP
plus OS Login to `ops-01` in project `application-review-platform`, zone
`asia-northeast3-a`.

The transferred bundle is verified again before a same-filesystem rename exposes it
at `/srv/arp/releases/incoming/<full-sha>/`. Existing identical content is idempotent;
different payload or handoff identity fails closed. The receipt contains only source
SHA, OCI digest, fixed repository, and workflow run ID. GitHub receives no runtime
secret and the workflow neither activates `app-01`/`edge-01` nor runs deployment,
migration, restart, or rollback mechanics.

The WIF resources, repository variables, and runtime are not currently applied.
Phase 4 will provision/bootstrap them; Phase 5 will execute and verify real deployment
and rollback. Phase 3B therefore makes no claim of successful GCP access.
