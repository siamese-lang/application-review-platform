# ADR-004 — Separate persistent Seoul runtime from temporary cross-region experiment resources

Status: ACCEPTED

Decision date: 2026-09-13

## Context

The project is running on a Google Cloud Free Trial account with $300 of promotional
credit and a 90-day validity window. The user explicitly prefers to spend the available
credit when doing so preserves useful failure domains, observability, workload isolation,
or recovery evidence. Cost minimization is therefore not a reason to collapse the
architecture.

The limiting factor is quota, not credit. M6 live evidence recorded these relevant
`asia-northeast3` limits before runtime recreation:

- E2 CPUs: 32;
- instances: 8;
- in-use addresses: 4;
- SSD total: 250 GiB.

M6 already retained a capacity workaround on `storage-03`: `e2-small` plus a
`pd-standard` boot disk. That keeps the seven-node Seoul runtime within the observed SSD
quota.

M7 adds the frozen `obs-01` observability failure domain. This uses the eighth Seoul VM
slot. Later milestones also require temporary resources such as `loadgen-01`, optional
`app-02`, `backup-01`, and DR verification VMs. Attempting to place all of them in Seoul
would either violate the 8-instance limit or tempt the project to collapse roles and
contaminate measurement boundaries.

## Decision

Use a two-tier GCP placement strategy.

### Persistent primary runtime

`asia-northeast3` (Seoul) remains the primary runtime region for the service and its
direct operational dependencies.

After M7 live activation the intended persistent Seoul set is:

- `edge-01`;
- `app-01`;
- `db-01`;
- `storage-01`;
- `storage-02`;
- `storage-03`;
- `ops-01`;
- `obs-01`.

M7 therefore intentionally consumes the recorded eighth Seoul instance slot.

`obs-01` starts with:

- `e2-standard-2`;
- 20 GiB `pd-standard` boot disk;
- 40 GiB `pd-standard` observability data disk;
- no public IP.

The standard persistent disks are a quota decision, not an attempt to weaken the
observability design. A `pd-balanced` `obs-01` boot disk would push the observed
SSD-backed footprint beyond the recorded 250 GiB Seoul limit.

### Temporary experiment/recovery resources

Resources whose purpose is to generate load, stage backup/recovery evidence, or exist only
for a bounded experiment should not consume permanent Seoul slots merely for locality.

Default placement for such resources is another GCP region, with
`asia-northeast1` (Tokyo) preferred when quota/capacity is available. Fallback placement
may use another nearby region when evidence or quota requires it.

This applies to:

- `loadgen-01` for k6;
- `backup-01` when introduced by the backup/recovery milestone;
- temporary DR verification VMs;
- other short-lived experiment resources that do not belong on the business data path.

A temporary `app-02` is different: if a scale-out experiment requires it to participate
in the actual Seoul application tier, its placement must be decided by the measured
experiment requirement. Do not silently move it cross-region merely to bypass quota.

## Workload measurement consequence

The frozen requirement that k6 run from a separate `loadgen-01` remains.

A Tokyo load generator still enters through the real public `edge-01` path and does not
consume application-host resources. Its network latency must be treated explicitly:

- k6 end-to-end latency includes cross-region client/network latency;
- Nginx upstream timing, Spring server metrics/traces, and PostgreSQL statistics are used
  to isolate server-side behavior;
- before/after performance comparisons must use the same load-generator region, dataset,
  workload, VU profile, and duration.

Do not colocate k6 on `obs-01`, `app-01`, or another measured service node simply to
avoid quota limits.

## Cost policy

Preserve meaningful failure and measurement boundaries even if that consumes promotional
credit.

Reduce cost by controlling runtime duration, not by collapsing architectural roles:

- repository-only work does not justify keeping temporary experiment VMs alive;
- temporary load/DR resources are deleted after the experiment;
- persistent runtime may be stopped during long repository-only gaps when operationally
  safe;
- evidence-producing runtime should be adequately sized when the test is active.

No milestone should be weakened merely to preserve unused Free Trial credit.

## Live safety gate

Before every new regional resource class is first applied:

1. run a read-only project/regional quota check;
2. review the exact OpenTofu plan;
3. confirm no persistent Seoul resource is unexpectedly replaced;
4. confirm the target region has the required instance/CPU/disk quota;
5. record any capacity workaround in repository evidence.

## Alternatives considered

### Collapse observability onto an existing VM

Rejected. It would save one instance slot but violate the frozen failure-domain principle
and contaminate later measurements.

### Run k6 on `obs-01` or `app-01`

Rejected. The workload generator would compete for measured CPU/memory/network resources
and weaken the performance evidence.

### Keep all temporary resources in Seoul

Rejected under the current Free Trial quota because M7 reaches 8/8 recorded instances.

### Shrink M7 solely to preserve credit

Rejected. The account has promotional credit available, and the project goal is credible
operational evidence rather than minimum cloud spend.

## Consequences

Positive:

- the final service/runtime architecture keeps meaningful role separation;
- M8–M11 can add temporary resources without dismantling M7;
- resource placement becomes an explicit engineering constraint rather than an ad-hoc
  workaround;
- later performance evidence can distinguish client/network latency from server latency.

Costs and risks:

- cross-region temporary resources require additional regional subnet/NAT/IaC work when
  first introduced;
- inter-region/public traffic can add latency and small network charges;
- backup/DR placement must still respect each milestone's recovery semantics;
- regional quota must be checked at execution time because Free Trial quota cannot be
  assumed from historical evidence.

## Superseded assumptions

This ADR does not change the application, database, storage, observability, or security
technology choices.

It supersedes only the implicit assumption that every future experiment, backup, or
recovery VM must be created in the primary Seoul runtime region.
