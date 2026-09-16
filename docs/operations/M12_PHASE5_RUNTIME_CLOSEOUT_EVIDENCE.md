# M12 Phase 5 — Runtime Lifecycle Closeout Evidence

Status: VERIFIED

Date: 2026-09-16 UTC  
Repository base: `d11fb2d68d57ae8eb2a3094829c04388ce5ffce3`

This record closes the final live GCP runtime lifecycle for the Application Review Platform.
It contains sanitized lifecycle evidence only. No OpenTofu state, credentials, private keys,
tokens, decrypted secret material, or runtime passwords are committed.

## Decision

The final portfolio does not require an always-on public demo.

The repository already retains:

- the final reviewer-facing portfolio narrative;
- interview/application compression;
- M9 PostgreSQL performance E5 evidence;
- M10 Garage endpoint reliability E5 evidence;
- M11 disaster-recovery E5 evidence;
- M6 immutable release/rollback supporting E5 evidence;
- reproducible OpenTofu/Ansible configuration.

README and portfolio materials do not depend on a live URL or live screenshot. Keeping the
eight-node Seoul runtime running would therefore add cost without adding a new verified claim.

Decision:

```text
M12_LIVE_DEMO_REQUIRED=NO
M12_RUNTIME_LIFECYCLE=DESTROY
```

## State handoff before destroy

The runtime state was still controlled from `ops-01`.

Before destroying `ops-01` itself:

1. current repository revision on `ops-01` was verified as
   `d11fb2d68d57ae8eb2a3094829c04388ce5ffce3`;
2. `tofu state list` reported 30 managed runtime resources;
3. the current state was exported with `tofu state pull`;
4. the exported state was transferred to a fresh Cloud Shell repository clone;
5. the transferred state again reported exactly 30 resources;
6. an additional pre-destroy state snapshot was retained outside Git.

The state snapshot remains operational material outside the repository and must not be committed.

## Reviewed destroy plan

The first reviewed destroy-only plan contained:

```text
Plan: 0 to add, 0 to change, 30 to destroy.
```

The plan covered the persistent Seoul runtime and its runtime-owned infrastructure:

- `edge-01`, `app-01`, `db-01`, `storage-01/02/03`, `ops-01`, `obs-01`;
- PostgreSQL, Garage, and observability data disks;
- reserved edge address;
- runtime firewall rules;
- runtime VPC/subnet/router/NAT;
- the runtime instance IAM member recorded in the state.

Temporary M10/M11 load, backup, PITR, and full-DR resources were already absent and were not
part of this plan.

The owner-bootstrap IAM/service-account root is not part of this runtime state and was not
claimed as destroyed by M12.

## Partial first apply and recovery

The first apply began deleting the reviewed 30-resource plan but Cloud Shell temporarily failed
to connect to the Google Compute API while deleting several firewall rules:

```text
dial tcp ...:443: connect: connection refused
```

The failed apply was not blindly replayed.

After the partial apply, the authoritative OpenTofu state contained only seven resources:

```text
google_compute_firewall.app_db
google_compute_firewall.edge_app
google_compute_firewall.edge_http[0]
google_compute_firewall.iap_ssh
google_compute_firewall.observability_app_probe
google_compute_firewall.telemetry_observability
google_compute_network.m4
```

A new destroy plan was generated from that updated state and reviewed:

```text
Plan: 0 to add, 0 to change, 7 to destroy.
```

That fresh plan was then applied successfully:

```text
Apply complete! Resources: 0 added, 0 changed, 7 destroyed.
```

This avoided reusing a stale pre-failure plan after partial infrastructure deletion.

## Final verification

Final OpenTofu state:

```text
tofu state list | wc -l
0
```

Post-destroy GCP inventory checks returned no runtime resources for:

- Compute Engine instances;
- persistent disks;
- reserved addresses;
- the `arp-m4` network;
- firewall rules attached to the `arp-m4` network.

Therefore:

```text
M12_RUNTIME_STATE_EMPTY=PASS
M12_RUNTIME_GCP_INVENTORY_EMPTY=PASS
M12_RUNTIME_CLOSEOUT=PASS
```

This verifies destruction of the repository-managed application runtime represented by the
M12 state. It does not claim that every resource in the GCP project, including separately
managed owner-bootstrap IAM/service-account resources or billing/project configuration, was
deleted.

## Reproducibility after destroy

Destroying the runtime does not remove the project evidence or design:

- OpenTofu and Ansible remain committed;
- architecture and ADRs remain committed;
- M6/M9/M10/M11 evidence remains committed;
- portfolio and interview material remain committed;
- the final runtime state snapshot remains outside Git only.

The final portfolio describes a system that was implemented and verified on GCP IaaS, not an
always-running hosted service.
