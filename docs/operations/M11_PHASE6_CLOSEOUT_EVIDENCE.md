# M11 Phase 6 Closeout Evidence

Status: FINAL  
Milestone: M11 Disaster Recovery  
Closeout date: 2026-09-16 UTC  
Closeout repository base SHA: `e70c768bea645000adead22e26ef24dc16ab10af`

## Scope

Phase 6 closed M11 without rerunning successful PITR or full-DR recovery paths merely to create
additional metrics.

Closeout covered:

- removal of temporary M11 backup, PITR, and full-DR infrastructure;
- restoration of retained Seoul VM power state after the Phase 4 quota workaround;
- removal of temporary PostgreSQL WAL-archive wiring after the backup repository was removed;
- retained service-path verification;
- final persistent OpenTofu no-drift verification;
- portfolio/evidence closeout.

## Retained recovery evidence

M11 retained the following verified chain:

1. independent backup foundation and WAL archive;
2. independent PostgreSQL PITR into a disposable recovery VM;
3. one verified PostgreSQL/Garage maintenance checkpoint;
4. full DR rebuild into separate Tokyo infrastructure;
5. exact checkpoint database/object restore;
6. checkpoint-compatible release activation;
7. normal-TLS HTTPS applicant/reviewer workflow;
8. repository-owned business/history/audit/attachment integrity verification;
9. explicit residual-limit decision;
10. temporary-resource cleanup and persistent-runtime no-drift.

Primary identities:

- PITR target: `2026-09-16T10:44:13.321143+00`;
- PITR source backup used by the Phase 2 experiment: `20260916-090503F`;
- whole-system checkpoint: `m11-checkpoint-20260916T121255Z`;
- checkpoint PostgreSQL backup: `20260916-121314F`;
- checkpoint object manifest SHA-256:
  `b6749631671f489160740c6e27c30d4aedb69e8cc80914cfc8253129ed0607c8`;
- checkpoint-compatible application/frontend release:
  `d90eb558bdb6317d49b0a7ce82148ddeb4b5babf`.

## Measured PostgreSQL PITR

Phase 2 recovered the PRE marker state and excluded POST.

Measured:

- marker-granularity recovery gap: **≤ 1.087882 seconds** before the requested target;
- DB PITR RTO to business/data verification: **27.229 seconds**.

These results met the frozen internal DB targets:

- RPO ≤ 5 minutes;
- RTO ≤ 30 minutes.

This remains a marker-granularity RPO claim, not a finer WAL replay-stop claim.

## Verified cross-store checkpoint and full DR

Checkpoint state before backup:

- PENDING: 0;
- DELETE_PENDING: 0;
- AVAILABLE: 17;
- FAILED: 0.

Checkpoint maintenance timings:

- frozen interval start → verified backup set: 76.718 seconds;
- frozen interval start → writes resumed: 98.711 seconds.

Full DR restored the checkpoint into new Tokyo edge/app/db/Garage VMs.

Verified results:

- exact checkpoint PostgreSQL backup restored;
- 21 manifest objects restored and independently key/size/SHA-256 verified;
- HTTPS SPA/API and applicant/reviewer business flow passed;
- recovery smoke final application: 10412 / APPROVED;
- restored reviewer/state ownership mismatches: 0;
- history transition/chain mismatches: 0;
- audit subject/actor mismatches: 0;
- checkpoint attachment uploader mismatches: 0;
- checkpoint AVAILABLE attachment rows verified against manifest/Garage: 17;
- checkpoint PENDING/FAILED/DELETE_PENDING: 0/0/0;
- `M11_FULL_DR_INTEGRITY=PASS`.

The smoke added one post-checkpoint attachment/object; it was explicitly separated from the
checkpoint data rather than counted as a restore mismatch.

## Timing limitation

Component timings were retained:

- full-DR PostgreSQL restore/invariant component: 16.051 seconds;
- Garage restore/verification component: 0.766 seconds.

These values are **not** added together or presented as full-DR RTO.

The exercise did not retain one authoritative end-to-end disaster/recovery start timestamp and
one corresponding business-ready completion timestamp. Therefore:

- no measured full-DR end-to-end RTO is claimed;
- no effective full-system RPO against one simulated disaster timestamp is claimed.

Phase 5 intentionally retained this evidence limitation and did not rerun the already-successful
recovery solely to manufacture a stronger number.

## Temporary infrastructure teardown

Before teardown, the retained live state contained:

- temporary `backup-01`;
- temporary `recovery-db-01`;
- six temporary `dr-*` service VMs;
- related temporary disks, subnet/router/NAT, public address, and firewall rules.

The reviewed destroy plan reported:

`Plan: 0 to add, 0 to change, 35 to destroy.`

The plan contained only M11 temporary resources. No retained Seoul VM or persistent service
disk was changed or destroyed.

Apply result:

- 0 added;
- 0 changed;
- 35 destroyed.

Post-apply inventory confirmed `backup-01`, `recovery-db-01`, and all `dr-*` instances
were absent.

## Retained Seoul runtime restoration

The Phase 4 GCP CPU-quota workaround had stopped retained:

- edge-01;
- app-01;
- obs-01.

After temporary-resource teardown, all three were restarted.

Retained Seoul runtime then showed edge/app/db/obs/ops as RUNNING, with storage-01/02/03
remaining retained.

A non-mutating HTTPS request through the retained public edge returned valid program data:

`M11_PHASE6_FINAL_SERVICE_PATH=PASS`

The Grafana health endpoint on `obs-01` also returned database `ok`.

## Teardown defect discovered and corrected

The infrastructure teardown correctly removed `backup-01`, but live inspection then found that
`db-01` still retained the Phase 1 pgBackRest archive drop-in:

- `archive_mode = on`;
- `archive_command = 'pgbackrest --stanza=arp archive-push %p'`.

Leaving this state would make the retained database continue trying to archive WAL to a deleted
temporary repository.

A repository-owned closeout playbook/wrapper was added rather than applying an undocumented
manual edit.

Two bounded defects were exposed in that cleanup path:

1. an extensionless `mktemp` inventory was not recognized by Ansible's YAML inventory plugin,
   causing `skipping: no hosts matched` before any database mutation;
2. after successful cleanup/restart, PostgreSQL rendered the disabled command as
   `off|(disabled)`, while the first assertion accepted only `off|`.

Both were corrected with focused static contracts.

Final live state:

- PostgreSQL archive state: `off|(disabled)`;
- `/etc/postgresql/16/main/conf.d/pgbackrest-archive.conf`: absent;
- `/etc/pgbackrest/pgbackrest.conf`: absent;
- result: `M11_ARCHIVE_CLEANUP=PASS`.

This is closeout hygiene, not a new recovery architecture.

## Final OpenTofu state

The final persistent-runtime plan used the retained storage-03 overrides and all temporary
M11 toggles disabled.

Result:

`No changes. Your infrastructure matches the configuration.`

The retained Seoul runtime therefore ended M11 with no unexplained OpenTofu drift.

## R5 disposition

M10 R5 logical corruption/PITR is formally satisfied by M11 Phase 2.

The evidence proves a bounded time-based PostgreSQL PITR into a separate recovery VM with:

- explicit pre/post marker boundary;
- PRE included;
- POST excluded;
- retained business invariants valid;
- measured DB PITR RPO/RTO within the frozen targets.

It does not imply PostgreSQL HA or transparent failover.

## CI / repository closeout chain

Relevant late-M11 runs:

- Phase 5 exact-head PR #165 CI: `35114507209` — SUCCESS;
- Phase 5 post-merge main CI: `35114585417` — SUCCESS;
- archive-cleanup PR #166 exact-head CI: `35116614058` — SUCCESS;
- inventory-suffix fix PR #167 exact-head CI: `35117095725` — SUCCESS;
- disabled-command assertion fix PR #168 exact-head CI: `35117497893` — SUCCESS;
- PR #168 post-merge main CI: `35117614524` — SUCCESS.

The final M11 closeout PR still requires its own exact-head and post-merge main CI before the
milestone is considered repository-closed.

## Final limitations

M11 does not prove:

- PostgreSQL automatic failover or HA;
- continuous multi-region application availability;
- simultaneous loss of the primary region and the single temporary backup repository;
- authoritative end-to-end full-DR RTO;
- effective full-system RPO against one simulated disaster timestamp.

GCP CPU quota also constrained the DR drill and required retained Seoul VM power-state changes
before the full temporary topology could be created.

## M11 conclusion

M11 demonstrates recoverability beyond process restart:

- independent DB PITR was measured and verified;
- a cross-store consistency checkpoint was created;
- PostgreSQL and attachment objects were restored into separate infrastructure;
- the recovered application passed real HTTPS business flow and integrity checks;
- temporary recovery infrastructure was removed;
- teardown residue was detected and corrected;
- retained Seoul service behavior and infrastructure state were revalidated.

The missing full-DR end-to-end timing boundary remains an explicit limitation rather than an
unsupported claim.
