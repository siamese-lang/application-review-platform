# M4 Cloud Deployment — Execution Plan

Status: ACTIVE

## Goal

Deploy the completed M3 application to the frozen GCP IaaS architecture with reproducible OpenTofu and Ansible configuration, split the public edge, application, PostgreSQL, Garage, and operations roles across separate VMs, preserve the frozen private-network and security boundaries, and prove that the real cloud deployment can execute the existing business and attachment workflow through HTTPS.

M4 establishes the cloud runtime and operations bootstrap only. It does not begin CI/CD deployment automation, backup/recovery implementation, observability, load generation, performance tuning, reliability fault injection, or DR exercises.

## Baseline and confirmed gaps

The repository state at M4 planning start is:

- M1 Business MVP, M2 Data Integrity, and M3 Attachment are complete;
- `main` is `d861c0e0c92e3a6f621afd472c1ca2fd2afb096a` and the post-M3 `main` workflow is green;
- no M4 active plan or M4 implementation PR exists;
- the GCP readiness baseline records project ID `application-review-platform`, region `asia-northeast3`, primary zone `asia-northeast3-a`, active billing, a budget alert, and Compute Engine API readiness;
- no runtime VM fleet is currently recorded as provisioned;
- `infra/opentofu/`, `config/ansible/`, and `deploy/` contain only repository skeleton placeholders;
- the application already accepts PostgreSQL and Garage connection values through environment variables, but there is no production-like VM configuration, artifact deployment path, or cloud runtime verification;
- no repository `.gitignore` currently protects OpenTofu state or generated local infrastructure files, so M4 must add explicit state/secret hygiene before any apply.

The readiness record is owner-confirmed rather than an independently queried live GCP inventory. M4 OpenTofu plan/apply and runtime verification become the authoritative evidence for resources actually created.

## Frozen M0 boundaries

M4 must preserve all of the following:

- GCP provides the IaaS substrate only: Compute Engine, Persistent Disk, VPC, Firewall, IAP, and Cloud NAT are the baseline cloud capabilities.
- Do not introduce Cloud SQL, GKE, managed Redis, managed application object storage, Kubernetes, Redis, Kafka/RabbitMQ, Elasticsearch, Keycloak, or another primary datastore/object store.
- `edge-01` is the only public service ingress.
- Application, database, Garage, operations, later observability, and later backup services do not expose public inbound service ports.
- Administrative access uses IAP rather than public SSH.
- Private VMs use Cloud NAT for required outbound package/image/dependency access.
- PostgreSQL remains a single primary and no database HA/failover claim is introduced.
- Spring Session JDBC remains in PostgreSQL.
- Garage remains the primary object store.
- Meaningful failure boundaries must not be collapsed into one all-in-one VM to save cost.
- Secrets, private keys, tokens, real personal data, and plaintext environment credentials must not be committed or emitted into CI/log evidence.
- M4 does not redesign M1–M3 application semantics to make deployment easier.

No ADR is expected because M4 implements the already-frozen architecture. Stop and propose an ADR if implementation would replace a frozen component or add a managed application service, another primary object store, another database, a new authentication system, or a different backup architecture.

## Current upstream facts confirmed for planning

The following current behaviors were checked against upstream documentation on 2026-09-10 and should be rechecked if implementation is delayed materially:

- Google Cloud IAP TCP forwarding can reach Compute Engine VMs without external IP addresses.
- The documented IPv4 source range for IAP TCP forwarding is `35.235.240.0/20`; SSH through IAP therefore needs a narrowly targeted TCP/22 firewall rule from that range.
- Google recommends OS Login for IAM-controlled SSH access; M4 should prefer OS Login rather than persistent metadata SSH keys.
- Public Cloud NAT lets VMs without external IPv4 addresses initiate internet connections and is configured regionally with a Cloud Router.
- `asia-northeast3-a`, `asia-northeast3-b`, and `asia-northeast3-c` are Seoul zones and currently support the E2 family.
- Let’s Encrypt IP-address certificates are generally available. They are short-lived certificates (about six days); current Certbot supports IP-address issuance. This makes trusted HTTPS possible without purchasing a domain, but renewal must be automated if this route is used.

These facts guide implementation; the repository configuration produced by M4 remains the lasting project record.

## Target M4 topology

M4 deploys the business data path and the operations host that are required before later operational milestones:

```text
Internet
  │ HTTPS
  ▼
edge-01: Nginx                         public IPv4
  │ TCP 8080 / private VPC
  ▼
app-01: Spring Boot                    private only
  ├─ TCP 5432 → db-01: PostgreSQL     private only
  └─ S3 API → Garage                  private only
              ├─ storage-01 / zone a
              ├─ storage-02 / zone b
              └─ storage-03 / zone c

IAP → ops-01                           private only
        │
        ├─ OpenTofu
        └─ Ansible → private nodes

private outbound → Cloud NAT → Internet
```

### M4 nodes

Provision the following roles as separate Compute Engine instances:

- `edge-01`
- `app-01`
- `db-01`
- `storage-01`
- `storage-02`
- `storage-03`
- `ops-01`

`storage-01`, `storage-02`, and `storage-03` must be placed across `asia-northeast3-a`, `asia-northeast3-b`, and `asia-northeast3-c` respectively so the final Garage topology already has distinct zonal placement before M9 reliability testing.

The three-node deployment in M4 does **not** itself constitute a node-loss/HA test and must not be described as proof of high availability. M9 owns deliberate storage/node fault scenarios and measured reliability claims.

Do not provision these later-milestone roles in M4:

- `backup-01` — M5/M10 as defined by backup/recovery work;
- `obs-01` — M6;
- `loadgen-01` — temporary M7+;
- `app-02` — temporary scale experiment only when later evidence requires it;
- DR replacement VMs — M10.

## Scope

### 1. OpenTofu infrastructure baseline

Implement the GCP infrastructure under `infra/opentofu/` as the canonical resource definition.

At minimum the OpenTofu configuration must define or manage:

- provider and OpenTofu version constraints;
- project, region, zone, CIDR, machine type, disk-size, and resource-name inputs;
- a dedicated custom VPC and regional subnet rather than relying on an accidental default network;
- a Cloud Router and Public Cloud NAT for private-node outbound connectivity;
- the single public edge IPv4 address;
- the seven M4 VM instances;
- persistent data disks for PostgreSQL and all three Garage nodes, separate from disposable boot disks where practical;
- narrowly scoped firewall rules;
- VM labels/tags or service-account targeting needed to make firewall intent readable;
- user-managed service accounts where a VM needs Google API permissions;
- OS Login metadata/configuration for administrative SSH access;
- outputs needed by the operations bootstrap and Ansible inventory.

Use configurable machine types rather than hard-coding a claim that a particular VM size is sufficient. Initial defaults should be deliberately small for functional deployment, with `edge-01` and `ops-01` smaller than the application/data roles where practical. A later size change is an operational experiment, not a performance claim.

Do not put database passwords, Garage secrets, TLS private keys, GitHub credentials, age private keys, or other secrets in OpenTofu variables, instance metadata, startup scripts, outputs, or state.

### 2. OpenTofu state and generated-file hygiene

Before the first apply:

- add repository ignore rules for `.terraform/`, `.terraform.lock.hcl` only if the project intentionally chooses not to commit the lock file (preferred: commit the lock file), `*.tfstate`, `*.tfstate.*`, plan files, generated inventories, decrypted secret files, and local override files;
- commit the provider lock file when initialization produces it so provider selection is reproducible;
- never commit OpenTofu state;
- do not introduce a GCS/managed remote-state backend merely for convenience because the frozen design expects the state to be controlled from `ops-01` and later copied to `backup-01`.

The initial owner-authenticated bootstrap may run from Google Cloud Shell or another authenticated owner environment because `ops-01` does not exist yet. This bootstrap shell is an execution environment, not an architecture component and must not become the durable source of truth.

After `ops-01` is available, securely transfer the current OpenTofu state to `ops-01`, keep it outside Git, and prove that an OpenTofu plan executed from `ops-01` against the same configuration does not propose unexpected recreation/drift. M5 will add durable operational/backup handling; M4 must not invent a different state-backend architecture.

### 3. Network and exposure rules

Implement only the paths required by the frozen architecture.

Minimum intended ingress/service paths are:

- Internet → `edge-01`: TCP 443 for HTTPS;
- Internet → `edge-01`: TCP 80 only when needed for ACME validation and/or immediate HTTP→HTTPS redirect;
- `edge-01` → `app-01`: application HTTP port (expected 8080) over the private VPC;
- `app-01` → `db-01`: PostgreSQL TCP 5432;
- `app-01` → Garage S3 endpoint: the pinned Garage S3 API port;
- Garage node ↔ Garage node: only the RPC/cluster ports required by the pinned Garage version;
- `ops-01` → managed private nodes: SSH/configuration ports required by Ansible;
- IAP TCP-forwarding source range → administrative SSH target(s): TCP 22 only.

The Garage admin API must not be publicly exposed. PostgreSQL must not be publicly exposed. Spring Boot port 8080 must not be publicly exposed.

Use private addresses or OpenTofu outputs for service configuration; do not add Cloud DNS solely to avoid managing the small M4 inventory unless a separate architecture decision later justifies it.

### 4. IAP, OS Login, and IAM bootstrap

Administrative access must be reproducible without public SSH keys or public SSH exposure.

M4 should:

- enable/use OS Login for the M4 instances;
- create the IAP TCP-forwarding firewall rule from `35.235.240.0/20` only to the intended administrative SSH targets;
- document the minimum owner IAM roles required to use IAP/OS Login without committing an account email into source;
- avoid project-wide `Owner`/`Editor` assignment to runtime service accounts;
- attach a dedicated user-managed service account to `ops-01` with only the Google Cloud permissions needed for the ongoing infrastructure operations implemented by M4;
- avoid attaching broadly privileged service accounts to `edge-01`, `app-01`, `db-01`, or Garage nodes when those workloads do not need Google API access.

The one-time owner bootstrap may use the project owner identity to create the initial operations service account and IAM bindings. After bootstrap, normal infrastructure execution should move to the scoped `ops-01` path rather than retaining copied personal credentials on the VM.

### 5. Ansible configuration baseline

Implement configuration under `config/ansible/` and execute it from `ops-01` after the bootstrap handoff.

Keep roles/components small and explicit. Expected responsibilities include:

- common OS/package/timezone/system prerequisites;
- `ops-01` tooling: Git, OpenTofu, Ansible, Java 21/build prerequisites, SOPS, age, and the GCP CLI only where actually required;
- `edge-01`: Nginx, reverse-proxy configuration, TLS material/renewal path, and service enablement;
- `db-01`: PostgreSQL package/service, dedicated data mount, application database/user provisioning, private listen/`pg_hba` rules;
- `storage-01/02/03`: pinned Garage installation/runtime, dedicated data mount, cluster configuration, layout/capacity assignment, replication configuration, bucket, and application access key;
- `app-01`: dedicated runtime user, Java 21 runtime, versioned application artifact, restricted environment configuration, and a systemd service;
- basic host firewall/service settings only where they complement rather than conflict with GCP firewall controls.

A second playbook execution against an already-configured stable environment must not destructively recreate data or rotate credentials unexpectedly. Idempotence is required at the level that matters operationally even if some harmless package/service checks report changes.

### 6. Secret handling with SOPS + age

M4 introduces the frozen secret-delivery path because the cloud application cannot run safely with default development credentials.

At minimum protect:

- PostgreSQL application password;
- Garage RPC/admin secrets required by the pinned version;
- Garage application access key and secret key;
- synthetic applicant/reviewer/admin passwords used for deployment verification;
- any TLS account material that must be retained and is actually secret.

Requirements:

- generate the age private key only in the controlled operations/bootstrap path; never commit it;
- commit only the public age recipient/configuration and SOPS-encrypted secret material when encrypted configuration is retained in Git;
- decrypt on `ops-01` only as required for configuration/deployment;
- write target environment files with restrictive ownership/mode;
- do not pass plaintext secrets through OpenTofu state, VM metadata, GitHub Actions logs, shell tracing, README examples, or evidence files;
- do not retain default `development-*` Garage credentials in the deployed service configuration.

If the whole synthetic M4 environment is deliberately destroyed to control cost, secrets may be regenerated on the next clean deployment. If data disks are retained, the corresponding decryption/secret material must also remain available through an explicitly controlled owner/operations path; do not silently destroy the only key required to operate retained data.

### 7. PostgreSQL deployment

`db-01` remains the single PostgreSQL primary.

M4 must:

- place database data on the intended persistent disk/mount;
- expose PostgreSQL only on the private VPC path required by `app-01` and restricted administrative paths;
- create the application database/user without committing plaintext credentials;
- let the deployed Spring Boot application run the existing Flyway V1–V4 migrations against a clean database;
- verify Hibernate schema validation succeeds after migration;
- retain the current transaction, optimistic-locking, audit, status-history, and Spring Session semantics.

Do not add replication, automated failover, pgBackRest, PITR, or backup jobs in M4. Those are later milestones.

### 8. Garage three-node deployment

Deploy the frozen Garage object store across `storage-01/02/03`.

Implementation must use one explicitly pinned Garage version on all nodes. Reuse the M3-tested version (`v2.4.1`) unless current official documentation identifies a concrete compatibility/security reason to choose another version; any version change must be explicit and verified.

M4 must configure:

- three nodes with distinct node/data identities;
- zonal placement `a` / `b` / `c`;
- the private RPC cluster path required by the pinned version;
- replication across the three-node cluster according to the frozen final storage intent;
- persistent data directories/disks;
- the `application-review` bucket and application credentials;
- the existing managed attachment prefix;
- an S3 endpoint reachable by `app-01` without exposing Garage publicly.

M4 proves that the cluster is configured and that the application can persist/read objects through it. It does **not** deliberately stop nodes, measure node-loss behavior, claim seamless endpoint failover, or run R1–R5 reliability scenarios. Those claims belong to M9.

### 9. Application artifact and runtime deployment

M4 must deploy the exact application revision under test without introducing CI/CD automation prematurely.

Preferred M4 bootstrap path:

1. the exact implementation commit is present on `ops-01`;
2. `ops-01` builds the application with the repository Maven Wrapper and Java 21;
3. Ansible copies a versioned JAR artifact to `app-01`;
4. `app-01` runs it under a dedicated system user with systemd;
5. runtime configuration is supplied through a restricted environment file populated from the controlled secret/config path.

This deliberately avoids a premature automated GitHub→GCP deployment pipeline. M5 will own CI/CD, deployment automation, migration/rollback procedure, and artifact-promotion policy.

The deployed environment must override at least:

- `DB_URL`
- `DB_USERNAME`
- `DB_PASSWORD`
- `GARAGE_ENDPOINT`
- `GARAGE_BUCKET`
- `GARAGE_REGION`
- `GARAGE_ACCESS_KEY`
- `GARAGE_SECRET_KEY`
- Garage addressing/prefix values when non-default
- attachment reconciliation timing only if the deployment requires an explicit environment value.

Do not change application authorization or attachment lifecycle semantics merely to simplify deployment.

### 10. Synthetic runtime users

The application has no public registration flow and the existing migrations intentionally do not contain reusable login credentials. M4 therefore needs a controlled, idempotent bootstrap for synthetic verification users.

Create one synthetic user for each required role (`APPLICANT`, `REVIEWER`, `ADMIN`) through the operations/configuration path after schema creation. Passwords must originate from encrypted/runtime secret inputs and only BCrypt hashes may be written to PostgreSQL.

Do not add fixed plaintext passwords or reusable credential hashes to Flyway migrations, source code, README files, tests, or evidence.

### 11. Edge and HTTPS

`edge-01` terminates HTTPS and reverse-proxies only to the private `app-01` endpoint.

M4 must prove the public application path through HTTPS; direct public access to Spring Boot is not acceptable.

Because a paid/custom domain is not part of the frozen baseline, the implementation may use the reserved public IPv4 address directly. Current Let’s Encrypt support makes a publicly trusted IP-address certificate practical without adding Cloud DNS or purchasing a domain. If that path is selected:

- use the reserved edge IPv4 address;
- request the short-lived IP certificate with a current compatible ACME client;
- automate renewal because the certificate lifetime is about six days;
- keep port 80 restricted to ACME validation/redirect behavior;
- ensure renewal failure does not expose secret material.

If a current upstream/client limitation prevents trusted IP-certificate issuance, M4 may temporarily use a self-signed certificate only if HTTPS transport is still verified with explicit trust configuration and the limitation is recorded as an M4 evidence note. Do not silently downgrade the final design to plain HTTP.

### 12. Runtime smoke verification

Add a repeatable M4 smoke-verification path rather than relying only on screenshots or process status.

The cloud smoke must prove at least:

- public HTTPS reaches `edge-01` and is reverse-proxied to `app-01`;
- application login succeeds with synthetic credentials;
- an applicant can create/edit/submit through the deployed application;
- a reviewer can reach the submitted application and execute an allowed review transition;
- applicant attachment upload reaches the deployed Garage cluster and becomes downloadable;
- the downloaded attachment bytes/SHA-256 match the uploaded synthetic fixture;
- unauthorized/private service ports are not exposed publicly;
- the application connects to PostgreSQL and Garage through private VPC paths rather than public endpoints.

The verification script may use `curl`/shell or another small dependency already justified by the project. Credentials must be supplied at runtime and must not be echoed.

Process-up checks such as `systemctl is-active` are useful diagnostics but are not sufficient proof of successful deployment.

### 13. Infrastructure verification and evidence

M4 must retain sanitized repository-backed evidence sufficient to support later portfolio and DR work.

Record at least:

- exact Git commit applied;
- OpenTofu version and locked provider version;
- `tofu plan`/apply summary without secrets;
- VM names, roles, zones, machine types, and whether they have external IPs;
- VPC/subnet/NAT/firewall summary proving the intended exposure boundary;
- IAP/OS Login access verification;
- Ansible configuration result and repeat-run/idempotence result;
- PostgreSQL/Flyway application startup verification;
- Garage cluster/layout health summary;
- HTTPS endpoint verification;
- end-to-end business/attachment smoke result;
- cleanup/stop/destroy decision after the milestone.

Evidence must not contain plaintext passwords, access keys, private keys, session cookies, Authorization headers, full SOPS-decrypted material, or sensitive request bodies.

If runtime verification is performed on implementation commit `X` and a later code/IaC/config change occurs, reapply/reverify the changed runtime. An evidence-only documentation commit may follow runtime verification as long as it clearly records the applied implementation SHA and no runtime configuration changed between the applied SHA and the final PR head.

### 14. Cost and lifecycle discipline

M4 must preserve role separation while minimizing unnecessary VM-hours.

- Keep VM machine type and disk size configurable.
- Do not provision later-milestone nodes early.
- Do not create `app-02`, load generators, or DR nodes for M4.
- Do not keep a failed/obsolete environment running while repeatedly editing IaC.
- After M4 evidence is captured, record whether the environment is retained for immediate M5 work, stopped, or destroyed with OpenTofu.
- If destroyed, destruction must be intentional and reproducible; repository IaC/evidence remains the proof of the milestone.
- A stopped VM may still incur disk/IP/storage charges; do not describe stop alone as zero cost.

## Likely files / components

M4 is expected to touch multiple infrastructure and operations components, including:

- `.gitignore`;
- `infra/opentofu/` provider/version files, variables, network, firewall/NAT, IAM/service-account, VM/disk resources, outputs, and provider lock file;
- `config/ansible/` inventory generation or inventory template, playbooks, group vars, and roles for common/ops/edge/app/db/Garage;
- `config/` SOPS configuration and encrypted environment material without plaintext secrets;
- `deploy/` controlled bootstrap/deploy/smoke scripts where appropriate;
- `app/src/main/resources/application.yml` only if a narrow runtime configurability gap is confirmed; do not change business behavior;
- `.github/workflows/baseline-ci.yml` only for static M4 repository verification such as OpenTofu format/validate and Ansible syntax checks; do not add automated cloud deployment in M4;
- `scripts/` for repository/static/runtime verification helpers as needed;
- `docs/operations/` for M4 runbook/evidence/actual deployed topology records;
- `README.md` for current milestone state only when implementation/completion status changes.

The exact file split may change, but durable infrastructure/configuration must remain in the repository rather than being recreated as undocumented Console clicks.

## Out of scope

Do not pull these into M4:

- automatic GitHub Actions deployment to GCP, artifact promotion, rollback automation, or release pipelines — M5;
- pgBackRest, WAL archiving, PostgreSQL backup/PITR, Garage object backup, maintenance checkpoint, OpenTofu-state backup to `backup-01` — M5/M10;
- `backup-01` deployment unless the approved M5 plan explicitly starts;
- Prometheus, Loki, Tempo, Grafana, Alertmanager, or Alloy — M6;
- `obs-01` — M6;
- bulk synthetic datasets or k6 — M7;
- performance tuning, measured indexes, JVM/DB tuning experiments, or scale-out — M8;
- deliberate VM/process/network/disk/storage fault injection and R1–R5 reliability experiments — M9;
- PostgreSQL automatic failover or enterprise HA claims;
- whole-system restore/PITR/full DR or new recovery VMs — M10;
- portfolio polishing or final architecture claims — M11;
- custom domain purchase, Cloud DNS, CDN, external load balancer, autoscaling, GKE, Cloud SQL, Secret Manager, managed Redis, or managed application object storage unless a later approved architecture decision explicitly changes the baseline.

## Verification

M4 is not complete unless all of the following are verified:

1. All existing M1–M3 GitHub Actions checks continue to pass on the exact final PR head.
2. OpenTofu formatting/initialization/validation checks pass for the committed configuration and provider selection is locked.
3. No OpenTofu state, plaintext secret, private key, token, decrypted SOPS file, or real personal data is committed.
4. A real OpenTofu apply in project `application-review-platform` creates the intended M4 resources in `asia-northeast3` without unapproved managed application services.
5. `edge-01`, `app-01`, `db-01`, `storage-01`, `storage-02`, `storage-03`, and `ops-01` exist as separate roles; no all-in-one shortcut is used.
6. `storage-01/02/03` are distributed across Seoul zones a/b/c and form the intended Garage cluster without claiming reliability testing.
7. Only `edge-01` has a public service endpoint; app, DB, Garage, and ops service ports are not publicly exposed.
8. Administrative SSH access succeeds through IAP/OS Login and direct public SSH is not required.
9. Private nodes can perform required outbound package/dependency access through Cloud NAT.
10. Firewall rules permit only the intended edge→app, app→DB, app→Garage, Garage-cluster, ops/admin, and IAP paths.
11. OpenTofu state is absent from Git and is transferred/usable from the controlled `ops-01` path after bootstrap.
12. Ansible configures all M4 roles from `ops-01` and a repeat run does not destructively recreate data or credentials.
13. PostgreSQL uses its intended persistent disk, accepts the application only on the private path, and the deployed app successfully applies Flyway V1–V4 with Hibernate validation.
14. The deployed app uses Spring Session JDBC and preserves the existing M2 data-integrity behavior.
15. The three Garage nodes use persistent storage, one pinned version, a configured layout/replication policy, and a private application S3 path.
16. Deployed DB/Garage/synthetic-user credentials are non-default runtime secrets and are not present in source, state, logs, or evidence.
17. `edge-01` serves the application through HTTPS and direct public access to app port 8080 is unavailable.
18. The cloud smoke verifies login, an applicant business flow, reviewer access/transition, attachment upload, and attachment download with matching bytes/SHA-256.
19. Runtime verification records the exact applied commit and sanitized topology/result evidence.
20. No M5+ implementation, unapproved ADR boundary change, or managed application cloud shortcut appears in the M4 diff.
21. The exact final PR head passes required GitHub Actions.
22. After merge, the `main` workflow succeeds.
23. The M4 plan is moved to `docs/plans/completed/` and README records M4 complete / M5 next only after all applicable conditions above are met.

## Execution workflow

After this plan is reviewed and merged to `main`:

1. Re-read `AGENTS.md`, `README.md`, `docs/WORKFLOW.md`, the frozen M0 documents, `docs/operations/GCP_BASELINE.md`, this plan, and the completed M3 plan.
2. Confirm the then-current `main`, active plan, open PRs, and CI state.
3. Create a fresh M4 implementation branch from that exact `main`.
4. Use Codex as the preferred workspace for the substantive multi-file OpenTofu/Ansible/deployment implementation.
5. Recheck current upstream GCP/IAP/Cloud NAT/OS Login and Garage version-specific behavior before pinning resource or port details.
6. Implement repository/static configuration first and run non-cloud checks before spending cloud resources.
7. Review the actual implementation diff against this plan and the frozen M0 architecture.
8. Perform an owner-authenticated initial OpenTofu bootstrap from Cloud Shell or another controlled environment only when the IaC is reviewable.
9. Bootstrap `ops-01`, transfer controlled infrastructure state, then run normal Ansible/configuration work from `ops-01`.
10. Deploy PostgreSQL, the three-node Garage cluster, the application artifact, and Nginx HTTPS path without starting M5 automation.
11. Run the runtime verification and retain sanitized evidence tied to the exact applied commit.
12. If any runtime/IaC/config change is required after verification, apply the smallest direct correction and repeat the affected verification.
13. Open/update the M4 PR, inspect the exact diff, and require final-head Actions success.
14. Only after all M4 done conditions are met, move this plan to completed and update README to M4 complete/M5 next.
15. Re-run final-head CI, merge, and verify the post-merge `main` workflow.
16. Record whether the GCP environment is retained for immediate M5, stopped, or destroyed through OpenTofu.

## Done when

M4 is done only when the M3 application is reproducibly deployed on the frozen split-role GCP IaaS topology; `edge-01` is the sole public service ingress; private administration/outbound paths use IAP and Cloud NAT; PostgreSQL and the three-node Garage cluster run on their intended private/persistent roles; OpenTofu and Ansible plus `ops-01` can reproduce/control the environment without committing state or secrets; HTTPS and the real business/attachment path are verified in GCP; sanitized evidence records the exact applied commit; no M5+ or unapproved architecture work is included; the M4 plan is completed; the final PR head is green; and the merged `main` workflow succeeds.
