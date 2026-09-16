# ADR-005 — Use an app-local Nginx proxy for Garage S3 endpoint failover

Status: ACCEPTED

Decision date: 2026-09-16

## Context

M10 R3 distinguished Garage replica durability from the application's client endpoint
availability.

R3a stopped the non-endpoint node storage-02 for about one minute. The application remained
configured to storage-01 and observed:

- 240 attachment attempts with 0% upload/download/delete/overall error;
- 480 non-attachment attempts with 0% error;
- storage-02 Garage telemetry `1 → 0 → 1`;
- PostgreSQL, application, storage-01, and storage-03 remained healthy;
- no attachment lifecycle residue.

R3b then stopped storage-01, which was the application's single configured Garage endpoint
(`http://10.40.0.41:3900`), while storage-02 and storage-03 remained healthy. The result was:

- existing attachment download error rate: 27.8481%;
- new attachment upload error rate: 27.0042%;
- non-attachment error rate: 0%;
- PostgreSQL and application probe remained healthy;
- storage-02 and storage-03 remained healthy;
- 64 FAILED attachment rows were retained from upload attempts made during the endpoint
  outage.

The storage cluster therefore retained replica availability while the application lost
attachment availability because all S3 traffic depended on one node address.

The Garage documentation explicitly describes Nginx as a supported reverse proxy and shows
an S3 upstream containing multiple Garage instances with load balancing, preserving the Host
header and disabling response buffering to a temporary file.

The current GCP firewall also reflects the old fixed-endpoint assumption: app-to-S3 traffic
is allowed only to the `arp-garage-endpoint` tag applied to storage-01.

## Decision

Add an Nginx S3 proxy on app-01 and make it the application's stable Garage endpoint.

The application endpoint becomes:

`http://127.0.0.1:3910`

The proxy listens only on loopback and balances S3 traffic across:

- storage-01:3900;
- storage-02:3900;
- storage-03:3900.

The proxy:

- preserves the incoming Host header so AWS Signature V4 remains valid;
- uses the three existing Garage S3 endpoints as equal upstreams;
- passively marks an upstream unavailable after a failed connection/request;
- retries eligible upstream failures against another Garage node;
- keeps the existing application attachment-size boundary;
- does not expose a new public or VPC listener.

The GCP firewall changes from a storage-01-specific target tag to the existing
`arp-storage` role tag so app-01 may reach port 3900 on all three Garage nodes.

The obsolete `arp-garage-endpoint` instance tag is removed.

Nginx is deliberately placed on app-01 rather than on a new VM:

- app-01 failure already makes the application unavailable, so the local proxy does not add a
  new independent business-path failure domain;
- no new persistent VM is required;
- Nginx is already an operated project technology;
- the change addresses only the measured Garage client-endpoint SPOF.

## Alternatives considered

### Keep the fixed storage-01 endpoint and document the limitation

Rejected for M10 because R3b measured a concrete attachment availability failure while two
healthy Garage replicas remained reachable. The mismatch between storage redundancy and
client reachability is material and has a bounded correction.

### Add a dedicated load-balancer VM

Rejected. It adds another persistent failure domain and consumes infrastructure solely to
route traffic that can be handled inside the existing application failure domain.

### Add a managed cloud load balancer or replace Garage

Rejected. Neither is required to address the measured problem, and both would expand the
technology and architecture surface beyond the smallest evidence-driven change.

### Implement endpoint rotation/retry inside the Java storage adapter

Rejected for this milestone. It couples S3 transport failover and request replay semantics to
application code. A reverse proxy keeps the existing S3 client contract and follows Garage's
documented deployment pattern.

### Run a Garage gateway node on app-01

Not selected. It would make app-01 a Garage cluster member and introduce additional Garage
configuration, cluster identity, and secret-management coupling when simple S3 proxying is
sufficient for the measured failure.

## Verification

The change is not considered effective merely because the proxy is deployed.

After repository CI and live deployment:

1. verify the proxy listens only on `127.0.0.1:3910`;
2. verify the application runtime endpoint is the loopback proxy;
3. verify app-01 can reach all three Garage S3 upstreams;
4. verify all three Garage nodes are healthy before injection;
5. rerun the same R3b storage-01 Garage-container outage;
6. require attachment existing-read, upload, downloaded-object, and delete error rates to be
   0% for the observed fault window;
7. require non-attachment and support error rates to remain 0%;
8. require PostgreSQL, application probe, storage-02, and storage-03 to remain healthy;
9. require storage-01 telemetry to show `1 → 0 → 1`;
10. inspect attachment lifecycle state after the retest and retain any unexpected residue.

If the equivalent R3b fault still causes attachment failures, preserve that result and do
not add another layer of HA without a new evidence-driven decision.

## Consequences

Positive:

- one Garage storage-node outage no longer needs to equal application attachment outage;
- Garage replica redundancy becomes reachable through the application data path;
- the correction uses an already-operated proxy technology and no new VM;
- the same R3b scenario provides a direct before/after reliability comparison.

Costs and risks:

- app-01 now operates a second local process on the attachment data path;
- Nginx passive failure detection/retry behavior must be tested rather than assumed;
- proxy configuration must preserve S3 request signing semantics;
- app-01 remains a single application failure domain;
- PostgreSQL remains a documented single-primary availability limitation.

## Superseded assumption

This ADR supersedes only the assumption that the application talks directly to a single
Garage node at storage-01:3900.

Garage remains the primary object store, the three storage-node topology remains unchanged,
and no second primary object store is introduced.
