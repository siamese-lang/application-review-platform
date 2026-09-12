# M6 Delivery Identity Contract

Status: PHASE 3A REPOSITORY CONTRACT

## Trust boundary

GitHub Actions exchanges an OIDC token from exactly
`https://token.actions.githubusercontent.com` through the bootstrap-managed Workload
Identity Pool provider. The provider maps `google.subject`, `repository`,
`repository_owner`, `ref`, `workflow_ref`, and `event_name`, and accepts a token only
when all of these deployment constraints hold:

- `repository == siamese-lang/application-review-platform`;
- `repository_owner == siamese-lang`;
- `ref == refs/heads/main`;
- `workflow_ref == siamese-lang/application-review-platform/.github/workflows/deploy-release.yml@refs/heads/main`;
- `event_name == workflow_dispatch`.

The service-account impersonation member is additionally a `principalSet` selected by
the exact repository attribute. Phase 3B will create the named workflow; its absence
in Phase 3A is intentional, so no current workflow can satisfy the complete condition.

## Dedicated identity and permissions

`arp-m6-github-deploy` is separate from `arp-m4-ops`. It has only:

- project `roles/compute.viewer` for `gcloud compute ssh/scp` instance and metadata lookup;
- project `roles/compute.osAdminLogin` for the controlled, sudo-capable OS Login handoff;
- project `roles/iap.tunnelResourceAccessor`, conditioned on
  `destination.ip == '10.40.0.50' && destination.port == 22`;
- `roles/iam.serviceAccountUser` on the specific `arp-m4-ops` service account attached
  to `ops-01`, rather than at project scope; and
- `roles/iam.workloadIdentityUser` on the deployment service account for only the
  exact repository attribute principal set.

The deployment identity receives no Compute or network administrator role, runtime
secret access, workload-service-account access, or owner-bootstrap/runtime apply
permission. GitHub is not federated directly to `arp-m4-ops`: that existing identity
retains its broad M4 operations permissions for the controlled path after entry to
`ops-01`, while compromise of the GitHub trust path remains bounded to the handoff.

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
