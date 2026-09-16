# Evidence Card — Garage replication survived but the fixed client endpoint did not

Status: FINAL
Milestone: M10
Evidence maturity: E5
Source release SHA: `70e1b7f3af1fc9022ccd3aeea2cf64c6cb036174`

## Context / assumption

The application stores attachment metadata in PostgreSQL and attachment bytes in a
three-node Garage cluster with replication factor 3. Before M10, the application still used
one fixed S3 endpoint on storage-01. The reliability question was whether replicated object
copies were enough to preserve application attachment availability when one Garage node
failed.

## Problem

The controlled R3a/R3b comparison showed that the failure outcome depended on which node was
lost.

With storage-02 stopped, attachment operations remained available. With storage-01 stopped,
the other two Garage nodes and PostgreSQL remained healthy and non-attachment business
requests still succeeded, but the application lost reliable attachment access because its
configured S3 endpoint was the failed node.

The R3b baseline recorded:

- 28.6920% overall attachment error rate;
- 27.8481% existing-object download error rate;
- 27.0042% upload error rate;
- 64 persistent FAILED attachment metadata rows created during the outage.

This demonstrated an endpoint-availability problem, not a Garage replication/durability
failure.

## Baseline

R3b baseline run:

`m10-r3b-20260916T061256Z-11b3a54f`

Environment:

- GCP IaaS runtime in Seoul;
- Spring Boot application on app-01;
- PostgreSQL single primary on db-01;
- Garage v2.4.1 across storage-01/02/03;
- Garage replication factor 3;
- real HTTPS/session/CSRF edge boundary;
- synthetic Dataset M / seed 20260914;
- fixed application Garage endpoint `http://10.40.0.41:3900`.

Fault:

- stop only the storage-01 Garage container;
- keep the outage bounded for about 60 seconds;
- leave storage-02, storage-03, PostgreSQL, app process, and edge runtime untouched.

Controls:

- non-attachment error rate: 0%;
- support-path error rate: 0%;
- PostgreSQL `pg_up`: min 1;
- application probe: min 1;
- storage-02/03 Garage: min 1;
- application PID unchanged.

## Analysis

Evidence narrowed the cause as follows:

1. R3a proved one non-endpoint Garage replica could be lost with 0% observed attachment error.
2. R3b showed the same class of single-node loss caused attachment failures only when the
   configured client endpoint itself disappeared.
3. PostgreSQL, application process, non-attachment flows, and the two peer Garage nodes
   remained healthy.
4. Existing pre-fault objects and new uploads both failed through the fixed endpoint.
5. FAILED metadata row timestamps fell entirely inside the observed endpoint outage.

The evidence therefore separated object replication from client endpoint availability.

## Options considered

1. Make no change and retain the limitation.
   - Valid as evidence, but the attachment-availability failure was material and the existing
     three healthy replicas were not being used by the client path.

2. Add PostgreSQL HA or another broader HA redesign.
   - Rejected as unrelated to the measured Garage endpoint failure and materially larger in
     scope.

3. Add a new managed load balancer/object-storage product.
   - Rejected because it would introduce a new product/failure domain when the existing
     app VM could provide the minimum failover boundary.

4. Run an app-local Nginx S3 proxy over all three Garage S3 endpoints.
   - Accepted as the smallest evidence-driven change. app-01 failure already makes the
     application unavailable, so the loopback proxy does not create a new independent
     business-path failure domain.

## Decision / action

ADR-005 introduced an Nginx listener on app-01 at `127.0.0.1:3910`.

The Spring application now uses that loopback endpoint. Nginx proxies to storage-01,
storage-02, and storage-03 on port 3900, preserves the incoming Host header for SigV4,
and retries eligible upstream failures. GCP firewall scope changed from the obsolete
single-endpoint tag to the existing `arp-storage` role tag.

Garage topology and replication factor remained unchanged.

## Verification

Same-fault retest:

`m10-r3b-retest-20260916T071400Z-70e1b7f3`

The same storage-01 Garage-container fault was repeated.

Observed:

- 240 attachment attempts;
- existing-read error rate: 0%;
- upload error rate: 0%;
- download-after-upload error rate: 0%;
- delete error rate: 0%;
- 480 non-attachment attempts, error rate 0%;
- support-path error rate 0%;
- fault-time FAILED/PENDING/DELETE_PENDING: 0/0/0;
- post-run FAILED/PENDING/DELETE_PENDING: 0/0/0;
- PostgreSQL and the application probe stayed healthy;
- storage-01 telemetry transitioned 1→0→1;
- storage-02/03 stayed healthy;
- application MainPID stayed 47204;
- full post-recovery HTTPS business/attachment smoke passed.

The corrective-change verdict was:

`M10_R3B_RETEST_CORRECTIVE_CHANGE=VERIFIED`

## Trade-off / limit

The app-local proxy adds one local configuration/runtime component and upstream failover
logic. It does not make app-01 highly available; app-01 remains a single application failure
domain.

This evidence covers one bounded single-Garage-node loss. It does not prove simultaneous
multi-node loss, network partitions, multi-region availability, or PostgreSQL HA.

The earlier 64 FAILED rows were reset as part of the guarded synthetic Dataset M reload before
the retest. The evidence does not claim that FAILED rows are automatically reconciled.

## Repository evidence

- code/config:
  - `docs/architecture/ADR-005-garage-endpoint-failover.md`
  - `config/ansible/roles/garage_proxy/`
  - `config/ansible/roles/app/templates/arp.env.j2`
  - `config/ansible/site.yml`
  - `infra/opentofu/firewall.tf`
  - `scripts/reliability/run-m10-r3b.sh`
  - `scripts/reliability/run-m10-r3b-retest.sh`
- focused tests:
  - `scripts/deploy/test-m10-garage-endpoint-proxy.sh`
  - M10 reliability static contract tests in baseline CI
- workload/experiment:
  - R3a `m10-r3a-20260916T055354Z-af5421e5`
  - R3b baseline `m10-r3b-20260916T061256Z-11b3a54f`
  - ADR-005 retest `m10-r3b-retest-20260916T071400Z-70e1b7f3`
- CI:
  - ADR-005 implementation PR #134 exact-head and post-merge CI passed
  - R3b retest harness PR #135 exact-head and post-merge CI passed
  - retest wrapper correction PR #136 exact-head and post-merge CI passed
- runtime evidence:
  - `docs/operations/M10_RELIABILITY_EVIDENCE.md`
  - `docs/operations/M10_PHASE6_CLOSEOUT_EVIDENCE.md`
  - retained run artifacts under `build/reliability/runs/` on ops-01

## Portfolio claim

Measured that a three-node replicated object store still lost application attachment
availability when the client used one fixed endpoint, then verified an app-local failover
proxy under the same storage-node fault: attachment errors fell from 28.6920% to 0% and no
new attachment lifecycle residue was created.
