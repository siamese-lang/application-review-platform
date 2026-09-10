# GCP Readiness and Lifecycle Baseline

Status: READY / M4 RUNTIME DESTROYED AFTER VERIFICATION
Recorded: 2026-09-10

## Project identity

- Project ID: `application-review-platform`
- Primary region: `asia-northeast3` (Seoul)
- Primary zone: `asia-northeast3-a`

The project ID is the canonical identifier for OpenTofu, scripts, CI/CD configuration, and operational documentation. Do not substitute a project display name for this value.

## Readiness baseline

The project owner confirmed the initial GCP preparation:

- the dedicated project was selected and billing enabled under the active Free Trial billing account;
- a project-scoped budget alert was configured;
- required Compute/IAM/IAP/OS Login APIs were enabled during M4 preparation.

The budget is an alerting guardrail, not a hard spending cap.

## M4 lifecycle outcome

M4 subsequently provisioned and verified the frozen seven-role IaaS topology using repository OpenTofu/Ansible. The real runtime evidence is retained in `docs/operations/M4_RUNTIME_EVIDENCE.md`.

After the M4 PR, post-merge `main` workflow, completed-plan state, and final CI evidence were captured, the runtime was intentionally destroyed through OpenTofu to stop unnecessary trial-credit consumption.

Current lifecycle statement:

- M4 application/runtime VM fleet: destroyed;
- M4 network/NAT/firewall/static edge-address resources: destroyed;
- M4 runtime persistent data disks: destroyed;
- controlled pre-destroy state snapshot: retained outside Git only;
- owner-bootstrap IAM/service-account root: intentionally separate from the runtime destroy and retained for later controlled provisioning unless explicitly removed.

A later milestone must not assume the old M4 VMs still exist. Re-provision from repository IaC when real cloud execution is required.

## Infrastructure conventions retained after ADR-001

- Final infrastructure remains defined under `infra/opentofu/` rather than reproduced manually in the Console.
- `edge-01` is the public ingress; app, DB, storage, observability, backup, and ops nodes do not expose public inbound services.
- After M5, `edge-01` also serves the React/Vite static release while `/api/**` is proxied to private `app-01`.
- A separate frontend VM is not part of the target topology.
- Administrative access to private VMs uses IAP.
- Private outbound access required for packages and container images uses Cloud NAT.
- Garage reliability testing distributes `storage-01`, `storage-02`, and `storage-03` across `asia-northeast3-a`, `asia-northeast3-b`, and `asia-northeast3-c` respectively.
- Temporary resources such as `loadgen-01`, `app-02`, and DR VMs are created only for the experiments that require them and are removed afterwards.

## Cost discipline

Preserve architecture and meaningful failure-domain boundaries while minimizing VM-hours. Do not keep a full seven-role environment running while work is purely repository/application development.

Re-provision real cloud resources only when the active milestone has a verification step that requires them, capture evidence promptly, and destroy or stop resources according to the documented lifecycle decision. A stopped VM is not assumed to be zero cost because disks/addresses/storage may continue to incur charges.

## Verification sources

Initial readiness items were owner-confirmed. M4 provisioned-state and destroy-state claims are backed by the retained M4 evidence and the controlled OpenTofu lifecycle procedure. Repository state remains the design source of truth; live GCP inventory is execution state and must be rechecked when a later milestone provisions resources again.
