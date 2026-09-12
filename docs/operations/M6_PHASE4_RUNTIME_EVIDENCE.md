# M6 Phase 4 — Live Runtime Evidence

Status: VERIFIED

Execution date: 2026-09-12 UTC  
Reviewed repository revision: `e40e78d73e48e7daf3e11641c8de65da5f49c0a0`

This record contains sanitized Phase 4 runtime evidence only. It intentionally omits plaintext passwords, Garage secrets, the age private key, OS Login SSH keys, session material, and decrypted SOPS content.

## Readiness and owner-bootstrap

The live GCP preflight succeeded for project `application-review-platform` in region `asia-northeast3` after enabling the required Security Token Service and Cloud Billing APIs.

Observed regional quota before runtime recreation included:

- E2 CPUs: limit 32, usage 0;
- instances: limit 8, usage 0;
- in-use addresses: limit 4, usage 0;
- SSD total: limit 250 GiB, usage 0.

The retained owner-bootstrap state was recovered outside Git and still tracked the existing `arp-m4-ops` and `arp-m4-workload` service accounts plus their owner/IAP/OS Login bindings.

The reviewed owner-bootstrap plan contained exactly seven additions and no changes or destroys. Apply created:

- `arp-m6-github-deploy`;
- the `arp-m6-github` Workload Identity Pool;
- the exact GitHub OIDC provider;
- repository-ID-constrained `roles/iam.workloadIdentityUser`;
- OS Admin Login for the deployment identity;
- IAP TCP forwarding restricted to `10.40.0.50:22`;
- service-account-user permission on the existing `arp-m4-ops` identity.

The resulting provider and deployment-service-account outputs were configured as GitHub repository variables `GCP_WORKLOAD_IDENTITY_PROVIDER` and `GCP_DEPLOY_SERVICE_ACCOUNT`. No service-account JSON key was created.

## Runtime recreation

The retained post-destroy runtime state was reused. It had the same M4 lineage and contained zero managed resources before recreation.

The M4 live capacity workaround was preserved rather than redesigning the topology:

- `storage-03`: `e2-small`;
- `storage-03` boot disk: `pd-standard`.

This keeps the frozen seven-role topology while avoiding the observed Seoul SSD-quota/capacity constraints.

Verified running nodes:

| Node | Zone | Machine type | Private IP | Public IP |
| --- | --- | --- | --- | --- |
| `edge-01` | `asia-northeast3-a` | `e2-small` | `10.40.0.10` | reserved edge IPv4 only |
| `app-01` | `asia-northeast3-a` | `e2-medium` | `10.40.0.20` | none |
| `db-01` | `asia-northeast3-a` | `e2-medium` | `10.40.0.30` | none |
| `storage-01` | `asia-northeast3-a` | `e2-medium` | `10.40.0.41` | none |
| `storage-02` | `asia-northeast3-b` | `e2-medium` | `10.40.0.42` | none |
| `storage-03` | `asia-northeast3-c` | `e2-small` | `10.40.0.43` | none |
| `ops-01` | `asia-northeast3-a` | `e2-small` | `10.40.0.50` | none |

Only `edge-01` has a public service address. The current reserved IPv4 is intentionally not treated as durable identity.

## Controlled operations path and secrets

`ops-01` was bootstrapped through IAP/OS Login and now holds the controlled runtime state and repository checkout for operations.

A fresh age key pair was generated on `ops-01`. The private key remains outside Git under the restricted operations path.

Fresh synthetic DB, Garage, and application-user credentials were generated on the controlled path, encrypted with SOPS, successfully decrypted for verification, and the plaintext staging file was removed. No secret value is recorded here.

During this execution, the repository scripts exposed an operational usability defect: `prepare-secrets.sh` and `configure-runtime.sh` assumed that the caller's current working directory was inside the Git checkout. The live work succeeded after entering the controlled repository path as root. The Phase 4 closeout change removes that unnecessary working-directory dependency by deriving the repository root from each script's own location.

## Runtime configuration

Ansible runtime configuration completed successfully without activating a backend/frontend release.

Verified state before Phase 5:

- PostgreSQL accepts connections on the intended private host;
- Nginx configuration validates and the service is active;
- the `arp` application service is installed/enabled;
- no active `/opt/arp/application.jar` exists yet;
- therefore Flyway V5 has not yet been applied in this fresh runtime and synthetic privileged users have not yet been inserted.

This is intentional. Phase 5 owns the first immutable backend activation, Flyway execution, final-schema privileged-user insertion, public/API business smoke, and rollback drill.

## Garage

Garage `v2.4.1` is healthy on all three storage nodes across Seoul zones a/b/c.

The applied layout reports replication factor 3 across three distinct zones, about 69.8 GiB total usable raw capacity and about 23.3 GiB effective capacity after replication.

The `application-review` bucket exists and the fresh application key has read/write/owner permission. Secret key material is not retained in this record.

## No-drift verification

Final OpenTofu plans for both:

- the runtime root controlled from `ops-01`; and
- the owner-bootstrap root controlled from Cloud Shell

reported no changes.

## Evidence boundary

Phase 4 proves live runtime recreation, keyless identity/IAP/OS Login readiness, controlled state/secrets handling, configuration of PostgreSQL/Garage/Nginx/application service prerequisites, and no infrastructure drift.

It does **not** yet prove:

- GitHub Actions WIF authentication by an actual deployment dispatch;
- exact OCI staging on `ops-01`;
- release activation;
- Flyway V5 execution;
- synthetic privileged-user insertion;
- public SPA/API business smoke;
- schema-compatible rollback.

Those are Phase 5 evidence. The primary M6 immutable-release/rollback portfolio candidate therefore remains below promotion until the real deploy/rollback drill succeeds.
