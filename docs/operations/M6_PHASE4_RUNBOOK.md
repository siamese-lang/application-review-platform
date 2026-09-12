# M6 Phase 4 — Runtime recreation runbook

Status: OPERATOR RUNBOOK; Phase 4A prepares this path but does not execute it.

## Fixed scope and prerequisites

- Project: `application-review-platform`; region: `asia-northeast3`.
- Run cloud commands only from an owner-authenticated, controlled operations environment.
- Never place OpenTofu state, plans, an age private key, or plaintext runtime secrets in the Git checkout.
- Do not activate an application/frontend release during Phase 4. Phase 3B remains undispatched.
- Use the reviewed `main` commit for the execution slice. Record its full SHA before continuing.

## Execution sequence

1. **Check out exact reviewed main.** Fetch `main`, detach/check out its reviewed full SHA, verify a clean worktree, and compare `git rev-parse HEAD` with the approved SHA.
2. **Run the read-only preflight.** Run `deploy/m6-runtime-preflight.sh`. Save sanitized output without account identifiers or credentials.
3. **Review readiness.** Confirm billing and every required API is enabled. Review project and Seoul quota output against 7 instances, approximately 14 E2 vCPUs, 1 regional address, and approximately 260 GiB balanced-disk demand. A displayed metric is not itself a sufficiency claim; resolve ambiguous metric scope manually. Do not shrink the topology automatically. Per-node machine/disk overrides remain the capacity-recovery mechanism.
4. **Recover owner-bootstrap state.** Locate the retained, nonempty owner-bootstrap state outside Git and restrict its permissions. If `arp-m4-ops` or `arp-m4-workload` exists but the retained state cannot be found, **STOP; do not apply**. Produce a controlled import/reconciliation plan instead of recreating or deleting retained identities blindly.
5. **Generate the owner-bootstrap plan.** Set absolute outside-Git `ARP_BOOTSTRAP_STATE_PATH` and `ARP_BOOTSTRAP_PLAN_PATH`, then run `deploy/tofu-bootstrap-plan.sh` with the reviewed bootstrap variables.
6. **Review the bootstrap delta.** A healthy plan must not unexpectedly recreate or destructively replace `arp-m4-ops` or `arp-m4-workload`. It should principally add/reconcile `arp-m6-github-deploy`, the GitHub Workload Identity Pool/provider, and constrained WIF/IAP/OS Login IAM. **STOP** on destructive retained-identity changes; a generated plan is not approval to apply.
7. **Apply the reviewed bootstrap plan.** From the owner-authenticated controlled environment, apply only the saved, reviewed bootstrap plan. This step is Phase 4B/live work, never a Codex or CI action.
8. **Capture delivery outputs.** Read the applied bootstrap outputs for `github_workload_identity_provider` and `github_deployment_service_account_email`. Configure their real values as repository variables `GCP_WORKLOAD_IDENTITY_PROVIDER` and `GCP_DEPLOY_SERVICE_ACCOUNT` before any Phase 3B dispatch. Never fabricate them or dispatch Phase 3B during Phase 4A.
9. **Select runtime state.** Prefer the retained post-destroy runtime state (zero managed resources) at an absolute outside-Git `ARP_TOFU_STATE_PATH`. If unavailable, an absent/new empty state is allowed only after the live preflight proves all seven old VM names absent; explicitly set `ARP_RUNTIME_ABSENCE_VERIFIED=yes`. Set an outside-Git `ARP_TOFU_PLAN_PATH`.
10. **Generate and review the runtime plan.** Run `deploy/tofu-init-plan.sh` with reviewed variables. The plan must recreate, not redesign, the frozen VPC/private-address/firewall/NAT topology and exactly `edge-01`, `app-01`, `db-01`, `storage-01`, `storage-02`, `storage-03`, and `ops-01`. Reject `obs-01`, `backup-01`, `loadgen-01`, `app-02`, GKE, Cloud SQL, managed Redis, a new load balancer, or other M7+ infrastructure.
11. **Apply the reviewed runtime plan.** Apply only the saved plan in the controlled environment.
12. **Verify topology.** Compare OpenTofu outputs and read-only Compute inspection with the seven expected role/name/private-address assignments and frozen edge/network boundary.
13. **Bootstrap `ops-01`.** Run `deploy/bootstrap-ops-local.sh` through IAP/OS Login from the approved owner path.
14. **Transfer/control runtime state.** Transfer the controlled runtime state to the protected `ops-01` operations path, verify it is the applied state, set restrictive permissions, and retain a controlled backup outside Git.
15. **Create age material.** Generate a fresh age key pair on the controlled operations path. Keep the private key outside Git with restrictive permissions; use only its public recipient in SOPS configuration.
16. **Create fresh secrets.** Copy `config/secrets/runtime.schema.yaml` to an outside-Git restricted plaintext file and populate fresh securely generated DB, Garage, and synthetic-user credentials. Garage application access keys must match `GK` plus 24 lowercase hexadecimal characters, application secrets must be 64 lowercase hexadecimal characters, and the RPC secret must satisfy Garage's expected format. Never print these values.
17. **Encrypt runtime configuration.** Set `AGE_RECIPIENT`, `PLAINTEXT_FILE`, and `ENCRYPTED_FILE`, then run `deploy/prepare-secrets.sh`. Confirm SOPS can decrypt on the controlled path. Remove plaintext according to that environment's storage procedure; do not claim filesystem-independent secure deletion.
18. **Configure without release activation.** Run `deploy/configure-runtime.sh` through the controlled Ansible path, excluding any application/frontend release activation or Phase 5 deployment/rollback command.
19. **Bootstrap Garage.** Run `deploy/bootstrap-garage.sh`; verify the three storage nodes, layout, bucket, and application key contract without logging secret material.
20. **Verify preconditions and sequencing.** Verify PostgreSQL, secret-file permissions/decryption, Garage, private connectivity, and service prerequisites. Do not apply V1–V5 manually with `psql`. Phase 4 prepares/tests the final-schema synthetic-user bootstrap and may confirm it refuses to run before V5 exists. Actual reviewer/admin/applicant insertion occurs only after the first Phase 5 backend startup has run Flyway V5, unless a separately approved Flyway-only schema activation path already exists.
21. **Run final no-drift plans.** From the controlled states, generate and review final owner-bootstrap/runtime plans. Record only sanitized no-drift evidence. Investigate every unexpected delta.

## Stop conditions

- Any missing required API, disabled billing, inaccessible quota report, unexpected old runtime VM, or unresolved quota/capacity issue.
- Retained owner-bootstrap resources exist but their state is missing, empty, or does not track both retained service accounts.
- A bootstrap plan replaces/deletes retained identities, or a runtime plan departs from the frozen seven-role topology.
- State, plans, private keys, or plaintext secrets would be written in the repository.
- Flyway V5 has not established the `users` schema when privileged synthetic insertion is attempted.
