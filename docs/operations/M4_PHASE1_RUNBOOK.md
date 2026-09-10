# M4 Phase 1/2 deployment runbook

Status: PHASE 1 REPOSITORY IMPLEMENTATION COMPLETE — PHASE 2 NOT EXECUTED — NO CLOUD RESOURCES CREATED

## Safety boundary

Phase 1 ends at repository/static verification. It never runs `tofu apply`, creates certificates, mutates IAM, or contacts target VMs. A human must review the exact Phase 2 plans before explicit applies. M4 remains active until the real cloud runtime and final-head CI satisfy the active plan.

## Two-state ownership model

M4 deliberately uses two local OpenTofu roots/states so the frozen owner-bootstrap/ops-operation boundary is executable without granting IAM administration to `ops-01`.

- `infra/opentofu/bootstrap/` is owner-controlled. It creates `arp-m4-ops` and `arp-m4-workload`, owner IAP/OS Login bindings, the ops service account's Compute/OS Login roles, and narrowly scoped `Service Account User` bindings on the two M4 service accounts. Its state stays with the owner-controlled bootstrap environment and is never handed to `ops-01`.
- `infra/opentofu/` is the ongoing runtime root. It manages VPC/firewall/NAT/address/disks/VMs and contains no service-account or project-IAM resources. It refers to the two bootstrap-created service accounts by deterministic project email. Only this runtime state is handed to `ops-01`.
- Do not grant Owner, Editor, Project IAM Admin, or Service Account Admin to the ops service account merely to make a monolithic state self-manage.

Both roots have been initialized during Phase 1 verification and their generated `.terraform.lock.hcl` files are committed. CI initializes from those locks with `-lockfile=readonly` and verifies they are not rewritten. Do not invent or hand-edit provider checksums.

## Owner-controlled Phase 2 bootstrap

1. In an owner-controlled Cloud Shell or equivalent authenticated environment, verify project `application-review-platform`, billing, the required Compute Engine/IAM/IAP/OS Login APIs, the exact reviewed PR commit, and OpenTofu 1.12.x. Do not copy owner Google or GitHub credentials to a VM.
2. Put the real `user:` or `group:` administrative principals in an ignored bootstrap tfvars file. Run `deploy/tofu-bootstrap-plan.sh -var-file=<ignored-bootstrap-file>`, review the saved IAM/service-account plan, then apply it only as an explicit separate Phase 2 command.
3. Run `deploy/tofu-init-plan.sh -var-file=<ignored-runtime-file>` for the runtime root, review the saved plan and costs, then apply it only as a separate manual Phase 2 command. The first runtime apply is owner-authenticated because `ops-01` does not exist yet.
4. Preserve the two states separately. Never copy the bootstrap IAM state to `ops-01`.

## Runtime state handoff

The runtime root uses an explicit local backend. After `ops-01` exists, transfer only its runtime state over the IAP-protected administrative path to `/srv/arp/state/terraform.tfstate`, mode 0600 inside the root-owned `/srv/arp/state` directory. On `ops-01` set:

```bash
export ARP_TOFU_STATE_PATH=/srv/arp/state/terraform.tfstate
```

Then run `deploy/tofu-init-plan.sh` against the exact reviewed repository revision. The resulting refresh plan must not propose unexpected recreation or IAM/service-account changes. M5/M10 own durable state backup architecture; do not add a remote backend in M4.

## Operations-host bootstrap without copied GitHub credentials

Use IAP + OS Login to reach `ops-01`; no public SSH rule is required. Prepare the exact reviewed repository revision in the owner-controlled environment and transfer the working tree/repository to `ops-01` over the IAP-protected path rather than placing a reusable GitHub credential on the VM. Verify `git rev-parse HEAD` on `ops-01` equals the reviewed PR head.

Run `deploy/bootstrap-ops-local.sh` once on `ops-01`. It creates an isolated Ansible virtual environment, installs the repository's supported Ansible-Core range, installs required collections, and executes `config/ansible/bootstrap-ops.yml` locally. The ops role installs Java/build prerequisites, OpenSSH client, PostgreSQL client, OpenTofu 1.12.6, SOPS 3.10.2, age, and controlled `/srv/arp` directories. Pinned OpenTofu/SOPS downloads are checksum verified.

## Ephemeral OS Login path from ops-01

All M4 instances keep `enable-oslogin=TRUE` and `block-project-ssh-keys=TRUE`. Guest attributes are enabled before first boot so the Google guest agent publishes each VM's SSH host keys.

`deploy/with-oslogin-ssh.py` is the required wrapper for ops-01 → private-node SSH automation. It:

1. verifies it is running with the attached `arp-m4-ops` service-account identity;
2. generates a temporary Ed25519 key (15-minute TTL by default);
3. registers only the public key through the OS Login API and discovers that service account's POSIX username;
4. reads the private-node SSH host keys through the authenticated Compute Engine guest-attributes API and writes a temporary `known_hosts` file;
5. exports the temporary identity to Ansible with `StrictHostKeyChecking=yes` and `IdentitiesOnly=yes`;
6. removes local key material on exit and best-effort deletes the OS Login public key; the server-side TTL remains the fail-safe.

Do not replace this with a persistent project metadata key, `StrictHostKeyChecking=no`, or an unauthenticated `ssh-keyscan` trust bootstrap.

`deploy/build-and-configure.sh` automatically invokes Ansible through this wrapper. Run the Garage cluster bootstrap as:

```bash
deploy/with-oslogin-ssh.py -- deploy/bootstrap-garage.sh
```

The ops service account has OS Admin Login for sudo-capable configuration and `Service Account User` only on the two M4 VM service accounts, not broad IAM administration.

## Inventory, build, and configuration

With the runtime backend initialized to the handed-off state, generate inventory using:

```bash
tofu -chdir=infra/opentofu output -json inventory | deploy/generate-inventory.py > config/ansible/inventory/generated.yml
```

The generated inventory contains private addresses/zones only; the ephemeral wrapper supplies the OS Login user and key. `deploy/build-and-configure.sh` builds the exact repository revision with the repository-root `./mvnw`, decrypts SOPS material only to a mode-0600 temporary file, and runs the Ansible site playbook through the ephemeral OS Login path.

Configuration order remains common/ops, PostgreSQL, Garage, application, then edge. PostgreSQL is a single primary on its persistent disk. Garage remains `dxflrs/garage:v2.4.1` on three zonally distinct persistent disks with replication factor 3; this is not a node-loss/HA experiment. The app JAR is versioned and runs as a dedicated system user. HTTPS terminates at `edge-01`; app/DB/Garage/ops service ports remain private.

## Secrets and synthetic users

Generate the age private identity only in the controlled owner/ops path and never commit it. Commit only encrypted secret material when retained. Do not place plaintext secrets in OpenTofu variables/state/metadata, GitHub Actions logs, repository files, or evidence.

After Flyway V1–V4 succeeds, run `deploy/bootstrap-synthetic-users.sh` from `ops-01` using runtime secret inputs. `postgresql-client` is an explicit ops prerequisite. The script creates missing APPLICANT/REVIEWER/ADMIN synthetic users using BCrypt hashes and does not rotate existing users.

## Phase 1 verification

The repository PR must pass, on its exact final head:

- repository baseline and existing PostgreSQL + Garage application verification;
- `tofu fmt -check`, provider initialization, and `tofu validate` for both OpenTofu roots;
- committed provider lock verification before the first reviewed apply;
- Ansible syntax for both the local ops bootstrap and the remote site playbook;
- Python compilation for inventory/OS Login helpers;
- deployment shell syntax and wiring checks that reject the old app-local Maven wrapper path, obsolete fixed branch check, missing state split, disabled host verification, or forbidden generated secret/state material.

Phase 1 does not claim runtime success because no GCP resources exist yet.

## Phase 2 runtime verification

After explicit reviewed applies, record sanitized evidence for the exact applied SHA: VM/zone/exposure/NAT/firewall summary, IAP + OS Login access, runtime state handoff and no-unexpected-change plan, repeat Ansible result, PostgreSQL/Flyway startup, Garage layout, HTTPS, and `deploy/cloud-smoke.sh` business/attachment results including SHA-256 equality. Do not run M5+ backup/observability/workload/performance/reliability/DR work in M4.
