# M4 Phase 1/2 deployment runbook

Status: PHASE 1 REPOSITORY IMPLEMENTATION — NO CLOUD RESOURCES CREATED

## Safety boundary

Phase 1 ends at formatting, provider initialization/validation, Ansible syntax, and shell checks. It never runs `tofu apply`, creates certificates, changes IAM, or contacts target VMs. A human must review the exact saved Phase 2 plan before an explicit apply. M4 remains active until cloud runtime evidence and final-head CI exist.

## Owner bootstrap and IAM

1. From an owner-controlled Cloud Shell, verify project `application-review-platform`, billing, Compute Engine/IAM/IAP APIs, current branch/commit, OpenTofu 1.12.x, and the locked Google provider. Do not copy owner credentials to a VM.
2. Put the real `user:` or `group:` principal in an ignored tfvars file. The configuration grants that principal OS Admin Login and IAP tunnel access. The IAP firewall source is only `35.235.240.0/20`; there is no public SSH rule.
3. The owner performs the first reviewed apply because `ops-01` and its identity do not yet exist. Runtime nodes use an unprivileged user-managed service account. `ops-01` receives Compute Admin, Compute Network Admin, and Service Account User—not Owner, Editor, or IAM Admin. IAM/service-account bootstrap remains owner-controlled.
4. Use `deploy/tofu-init-plan.sh -var-file=<ignored-file>` to save a plan. Inspect all resources and costs. Apply only as a separate manual Phase 2 command after review.

## State handoff

No remote backend is configured. State starts in the owner-controlled bootstrap directory, never in Git. After `ops-01` exists, copy it over an IAP-protected channel into `/srv/arp/state` (mode 0700), delete uncontrolled copies, and run a refresh plan from that path. M5/M10 own durable state backup architecture. Do not improvise a GCS backend here.

## Inventory and operations host

Pipe `tofu output -json inventory` to `deploy/generate-inventory.py > config/ansible/inventory/generated.yml`; this file is ignored. Bootstrap `ops-01` through IAP, clone the exact commit, install the `ops` role prerequisites, move state as above, and conduct private-node configuration from `ops-01`. Build/deploy uses `deploy/build-and-configure.sh`; it decrypts only to a mode-0600 temporary file and removes it.

## SOPS and age

Generate the age identity only in Cloud Shell/`ops-01` controlled storage (`age-keygen -o /srv/arp/secrets/age-identity.txt`, mode 0600). Copy only its public recipient into a real `.sops.yaml`; do not commit a fake recipient. Populate `config/secrets/runtime.schema.yaml` outside Git, then run `deploy/prepare-secrets.sh`. Only `*.enc.yaml` may be retained in Git. Never put secrets in OpenTofu variables, metadata, state, plans, command-line arguments, or evidence. Preserve the private identity while retained disks still depend on these secrets.

## Configuration sequence

1. Run common/ops roles, then PostgreSQL. The dedicated disk is mounted at `/srv/postgresql`; PostgreSQL listens on localhost and `db-01` private IP, with `pg_hba.conf` allowing only `arp_app` from `app-01`. Existing database users/passwords are not rotated.
2. Run Garage on three zonally distinct persistent disks using exactly `dxflrs/garage:v2.4.1`. The shared RPC secret and application keys come from decrypted inputs; node identity/data are local. Run `deploy/bootstrap-garage.sh` once/repeatedly to connect nodes, assign a/b/c zones/capacity, apply replication factor 3, and create/authorize the bucket. The application endpoint is private `storage-01:3900`; this is **not endpoint HA** and node-loss testing is M9.
3. Build the exact commit with Java 21/Maven Wrapper. The app role installs a versioned JAR, restricted environment, dedicated user, and systemd unit. After Flyway V1–V4 succeeds, run `deploy/bootstrap-synthetic-users.sh` with decrypted environment inputs. It inserts missing APPLICANT/REVIEWER/ADMIN users using BCrypt and does not rotate existing users.
4. Supply trusted IP-certificate files to the edge role. Use a current Certbot/ACME client capable of short-lived IP certificates and install an operator-tested renewal hook that reloads Nginx. If current issuance fails, generate no repository artifact: record the limitation, use an operator-created self-signed certificate, explicitly trust it with `CURL_CA_BUNDLE`, and keep HTTPS. Nginx redirects HTTP and proxies only to private `app-01:8080`.

## Verification and evidence

Run `deploy/cloud-smoke.sh` with HTTPS URL, synthetic applicant/reviewer credentials, and a synthetic attachment fixture. It handles cookie jars and CSRF, verifies create/edit/upload/download/submit and reviewer start/approve/download, and compares both downloaded SHA-256 values without printing credentials/cookies. Separately record sanitized instance/IP/firewall/NAT/IAP, OpenTofu plan/apply summary, repeat Ansible result, Flyway startup, Garage layout, exact applied SHA, and whether resources are retained/stopped/destroyed. Never claim Phase 1 smoke success: no endpoint exists yet.
