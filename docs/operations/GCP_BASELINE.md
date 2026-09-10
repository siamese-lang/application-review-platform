# GCP Readiness Baseline

Status: READY FOR M1 / PREPARED FOR M4
Recorded: 2026-09-10
Verification source: project-owner confirmation from the GCP Console

## Project identity

- Project ID: `application-review-platform`
- Primary region: `asia-northeast3` (Seoul)
- Primary zone: `asia-northeast3-a`

The project ID is the canonical identifier to use later in OpenTofu, scripts, CI/CD configuration, and operational documentation. Do not substitute a project display name for this value.

## P0-C readiness completed

The project owner confirmed completion of the following preparation in the GCP Console:

- the dedicated project is selected and billing is enabled under the active Free Trial billing account;
- a project-scoped budget alert is configured;
- Compute Engine API is enabled;
- no application/runtime VM fleet has been provisioned yet.

The budget is an alerting guardrail, not a hard spending cap.

## M4 infrastructure conventions

These values are preparation only; infrastructure is not created during P0-C.

- Final infrastructure is defined under `infra/opentofu/` rather than reproduced manually in the Console.
- `edge-01` is the public ingress; app, DB, storage, observability, backup, and ops nodes do not expose public inbound services.
- Administrative access to private VMs uses IAP.
- Private outbound access required for packages and container images uses Cloud NAT.
- Garage reliability testing should distribute `storage-01`, `storage-02`, and `storage-03` across `asia-northeast3-a`, `asia-northeast3-b`, and `asia-northeast3-c` respectively when that milestone is reached.
- Temporary resources such as `loadgen-01`, `app-02`, and DR VMs are created only for the experiments that require them and are removed afterwards.

## Cost discipline

Preserve architecture and failure-domain boundaries while minimizing VM-hours. Do not collapse the final operational topology into one all-in-one VM solely to reduce cost. Do not provision the M4 VM fleet before the milestone requires it.

## Verification note

ChatGPT does not have direct access to the GCP Console in this project. The readiness items above are recorded as owner-confirmed configuration, not as independently queried GCP state. Later OpenTofu plans and runtime verification will provide repository-backed evidence for provisioned resources.