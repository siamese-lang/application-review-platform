# M4 Cloud Deployment — Runtime Evidence

Status: VERIFIED_PENDING_MERGE

Verification date: 2026-09-10 UTC

This record contains sanitized M4 runtime evidence only. It intentionally omits passwords, access-key values, private keys, session cookies, decrypted SOPS material, and other credentials.

## Revision and CI evidence

- Runtime infrastructure was initially applied from commit `2c7b109b21dad4d538e499fa9cf51bfb2a0ba4f1`.
- The final application/runtime verification revision was `084b5d74250396d0a9f037b97290a9fe6c5a316c`.
- The final application artifact deployed to `app-01` was versioned with short SHA `084b5d742503` and the service was active after deployment.
- GitHub Actions run `34499659298` passed all jobs for exact head `084b5d74250396d0a9f037b97290a9fe6c5a316c`, including repository baseline, application tests, M4 static infrastructure checks, and the detailed-page rendering regression coverage added after runtime smoke exposed a Thymeleaf model-name collision.
- This evidence document is an evidence-only follow-up commit. No runtime infrastructure or application configuration is changed by this document.

## Toolchain and infrastructure state

- OpenTofu: `1.12.6`.
- Locked Google provider: `hashicorp/google` `7.46.1`.
- GCP project: `application-review-platform`.
- Region: `asia-northeast3`.
- Runtime state was transferred out of Git to the controlled `ops-01` path and remained usable there.
- A final OpenTofu plan from `ops-01`, using the transferred runtime state and final repository configuration, reported no changes.

### Verified M4 nodes

| Node | Zone | Machine type | Service exposure |
| --- | --- | --- | --- |
| `edge-01` | `asia-northeast3-a` | `e2-small` | public HTTPS ingress; private VPC address |
| `app-01` | `asia-northeast3-a` | `e2-medium` | private only |
| `db-01` | `asia-northeast3-a` | `e2-medium` | private only |
| `storage-01` | `asia-northeast3-a` | `e2-medium` | private only |
| `storage-02` | `asia-northeast3-b` | `e2-medium` | private only |
| `storage-03` | `asia-northeast3-c` | `e2-small` | private only |
| `ops-01` | `asia-northeast3-a` | `e2-small` | private only; administrative access through IAP/OS Login |

`storage-03` used the explicit M4 per-node capacity workaround (`e2-small`) and a `pd-standard` boot disk after live zonal-capacity and SSD-quota constraints were observed. This did not change the frozen role separation or three-zone Garage data layout.

Only `edge-01` had the public service endpoint. Application, PostgreSQL, Garage, and operations service ports remained private. Private-node outbound dependency/package access used Cloud NAT. Administrative SSH through IAP + OS Login was verified; direct public SSH was not required.

## Configuration evidence

- Ansible configuration succeeded for all seven M4 roles from `ops-01`.
- PostgreSQL was configured as the single private primary on its intended persistent data mount.
- The deployed Spring Boot service started successfully with Hibernate schema validation and Flyway migrations V1–V4 recorded successful.
- Synthetic `APPLICANT`, `REVIEWER`, and `ADMIN` users were present with runtime-generated passwords stored only as BCrypt hashes in PostgreSQL; existing accounts were not rotated by repeat bootstrap.
- The final app-only redeployment for revision `084b5d74250396d0a9f037b97290a9fe6c5a316c` completed with `failed=0`, and `systemctl is-active arp` returned `active`.

## Garage evidence

- Garage version: `v2.4.1` on all three storage nodes.
- Nodes were placed across Seoul zones a/b/c and connected over private addresses.
- The live layout applied successfully with replication factor `3` across the three zones.
- Reported usable raw capacity was about `69.8 GiB`, corresponding to about `23.3 GiB` effective capacity at replication factor 3.
- Bucket `application-review` existed and the synthetic application key had read/write/owner permissions for that bucket.
- No Garage access-key or secret-key value is recorded here.

This proves the configured three-node private object-store path and successful application object persistence/readback. It is not a node-loss, endpoint-failover, or high-availability test; those remain later-milestone reliability work.

## HTTPS evidence

- Reserved edge public IPv4 used for M4 verification: `8.230.11.152`.
- `edge-01` terminated HTTPS and reverse-proxied to private `app-01:8080`.
- HTTP redirected to HTTPS.
- A publicly trusted Let's Encrypt short-lived IP-address certificate was issued for the edge IP.
- Nginx configuration validation succeeded.
- The repository-managed certificate renewal timer was enabled and active.
- Direct public application-port exposure was not used.

Runtime verification exposed that Spring initially generated `http://` absolute redirects behind the HTTPS reverse proxy. The application was corrected to process forwarded headers, redeployed, and reverified over HTTPS.

## End-to-end business and attachment smoke

The final repeatable cloud smoke passed against the public HTTPS endpoint on application `6`:

1. HTTPS reachability.
2. Applicant authentication.
3. Program lookup.
4. Draft application creation and detail rendering.
5. Attachment upload to the deployed Garage path.
6. Applicant attachment download with SHA-256 equality against the uploaded fixture.
7. Draft edit.
8. Submission.
9. Reviewer authentication and review-page access.
10. Review start.
11. Approval.
12. Reviewer attachment download with the same SHA-256 equality check.

Final smoke result:

```text
PASS: HTTPS, applicant create/edit/upload/download/submit, reviewer start/approve/download, and SHA-256 equality (application 6).
SMOKE_EXIT=0
```

Post-smoke database verification confirmed application `6` in final state `APPROVED` with status-history transitions:

```text
DRAFT -> SUBMITTED
SUBMITTED -> IN_REVIEW
IN_REVIEW -> APPROVED
```

The attachment row was `AVAILABLE`, and its stored SHA-256 matched the local synthetic fixture SHA-256. The exact hash value is not needed for the milestone claim and is omitted from this sanitized record.

The first full cloud smoke also exposed a Thymeleaf 3.1 context-variable collision: using the model name `application` caused detailed pages to resolve ServletContext application scope rather than the domain record. Applicant, reviewer, and admin detailed-page model names were changed to `applicationRecord`, detailed-page render regression coverage was added, the exact head CI passed, the application was redeployed, and the full cloud smoke then passed.

## M4 boundary statement

M4 did not introduce Cloud SQL, GKE, managed Redis, managed application object storage, an external load balancer, CI/CD cloud deployment, backup/PITR implementation, observability, performance tuning, deliberate failure injection, or DR. The frozen IaaS role separation and existing M1–M3 business/attachment semantics were preserved.

## Lifecycle decision

The live M4 runtime is retained only through PR merge and the required post-merge `main` workflow verification. After those M4 completion gates are captured, the runtime will be intentionally destroyed with the controlled OpenTofu state to stop unnecessary trial-credit consumption. Repository IaC, this sanitized evidence, and the controlled state backup remain the milestone record. A stopped VM alone is not treated as zero cost.
