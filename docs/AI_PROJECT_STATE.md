# AI Project State — Fast Resume Checkpoint

Status: COMPLETE  
Last updated: 2026-09-16 UTC

This file is the short execution checkpoint for ChatGPT/Codex sessions. It is not an
architecture document, ADR, milestone plan, or evidence record.

## Resume protocol

1. Read `AGENTS.md`.
2. Read this file.
3. Read the active milestone plan under `docs/plans/active/` when one exists.
4. Inspect only directly relevant repository files, PRs, workflow runs, or live output.
5. Use current GitHub state over chat history.

## Current project checkpoint

Repository: `siamese-lang/application-review-platform`

Completed milestones:

- M1 Business MVP
- M2 Data Integrity
- M3 Attachment
- M4 Cloud Deployment
- M5 Web/API & Product Surface
- M6 Operations & Delivery
- M7 Observability
- M8 Workload
- M9 Performance
- M10 Reliability
- M11 Disaster Recovery
- M12 Portfolio

M11 completed plan:

`docs/plans/completed/M11-disaster-recovery.md`

M11 retained evidence:

- Phase 1 backup foundation:
  `docs/operations/M11_PHASE1_BACKUP_FOUNDATION_EVIDENCE.md`;
- Phase 2 independent PostgreSQL PITR:
  `docs/operations/M11_PHASE2_PITR_EVIDENCE.md`;
- Phase 3 cross-store checkpoint:
  `docs/operations/M11_PHASE3_CHECKPOINT_EVIDENCE.md`;
- Phase 4 full DR:
  `docs/operations/M11_PHASE4_FULL_DR_EVIDENCE.md`;
- Phase 5 residual decision:
  `docs/operations/M11_PHASE5_RESIDUAL_DECISION_EVIDENCE.md`;
- Phase 6 closeout:
  `docs/operations/M11_PHASE6_CLOSEOUT_EVIDENCE.md`;
- portfolio evidence card:
  `docs/portfolio/M11_DISASTER_RECOVERY_EVIDENCE.md`.

## M11 retained result

Independent PostgreSQL PITR:

- requested target: `2026-09-16T10:44:13.321143+00`;
- PRE state included / POST state excluded;
- marker-granularity recovery gap: ≤ 1.087882 seconds;
- measured DB PITR RTO: 27.229 seconds;
- frozen DB targets RPO ≤5 minutes and RTO ≤30 minutes were met.

Verified whole-system checkpoint:

- checkpoint: `m11-checkpoint-20260916T121255Z`;
- PostgreSQL backup: `20260916-121314F`;
- object manifest SHA-256:
  `b6749631671f489160740c6e27c30d4aedb69e8cc80914cfc8253129ed0607c8`;
- checkpoint attachment state: 17 AVAILABLE, 0 PENDING, 0 DELETE_PENDING, 0 FAILED;
- frozen start → backup-set verification: 76.718 seconds;
- frozen start → writes resumed: 98.711 seconds.

Full DR:

- separate Tokyo DR topology restored from the verified checkpoint;
- checkpoint-compatible backend/frontend release:
  `d90eb558bdb6317d49b0a7ce82148ddeb4b5babf`;
- exact 21-object checkpoint restore/verification passed;
- HTTPS applicant/reviewer workflow passed;
- restored business/history/audit/attachment integrity verifier passed;
- `M11_FULL_DR_INTEGRITY=PASS`.

Timing limitation:

- DB and Garage component timings were retained;
- no authoritative end-to-end full-DR recovery start/business-ready end boundary was retained;
- therefore no full-DR RTO or effective full-system RPO is claimed.

## M11 closeout

- reviewed teardown: 0 add, 0 change, 35 destroy;
- temporary `backup-01`, `recovery-db-01`, and all `dr-*` resources removed;
- retained Seoul `edge-01`, `app-01`, and `obs-01` restored after the quota workaround;
- retained service path verified after restart;
- teardown review exposed stale pgBackRest WAL-archive wiring on `db-01`;
- repository-owned cleanup disabled archiving and removed stale repository configuration;
- final DB archive state: `off|(disabled)`;
- final retained service path: PASS;
- final persistent OpenTofu plan: no changes.

M10 R5 logical corruption/PITR is now formally satisfied by M11 Phase 2.

## Portfolio checkpoint

Final primary stories:

- M9 PostgreSQL performance diagnosis — E5;
- M10 Garage endpoint failure and same-fault failover revalidation — E5;
- M11 disaster recovery correctness — E5.

M6 immutable release + rollback remains the high-value supporting delivery/change-control story.

Final portfolio narrative:

`docs/portfolio/PROJECT_PORTFOLIO.md`

Interview/application packet:

`docs/portfolio/INTERVIEW_PACKET.md`

## Project closeout

Current milestone: **none — M1–M12 complete**.

M12 completed plan:

`docs/plans/completed/M12-portfolio.md`

M12 runtime closeout evidence:

`docs/operations/M12_PHASE5_RUNTIME_CLOSEOUT_EVIDENCE.md`

Final portfolio entry:

`docs/portfolio/PROJECT_PORTFOLIO.md`

Interview/application packet:

`docs/portfolio/INTERVIEW_PACKET.md`

The final Seoul runtime was intentionally destroyed after evidence retention:

- reviewed initial destroy plan: 0 add / 0 change / 30 destroy;
- partial first apply encountered transient Compute API connection refusal;
- remaining state: 7 resources;
- reviewed fresh plan: 0 add / 0 change / 7 destroy;
- final OpenTofu state: 0 resources;
- final runtime instance/disk/address/network/firewall inventory checks: empty.

No live demo is required for the retained portfolio. Repository IaC and sanitized evidence are
the durable record.

## Do not revisit unless new evidence requires it

- completed M1–M11 implementation/recovery drills;
- M6 rollback drill;
- M7 observability closeout;
- M8 workload baselines;
- M9 measured SQL intervention;
- M10 fault experiments;
- M11 PITR/full-DR recovery paths.

## Short resume prompt

> @GitHub `siamese-lang/application-review-platform`의 현재 `main`을 source of truth로 사용하라.  
> M1–M12는 완료되었고 live GCP runtime은 M12 closeout에서 의도적으로 destroy되었다.  
> 먼저 `AGENTS.md`, `docs/AI_PROJECT_STATE.md`, `docs/portfolio/PROJECT_PORTFOLIO.md`를 읽어라.  
> 새로운 구체적 요구사항이나 evidence gap이 없다면 완료된 부하·장애·복구 실험이나 아키텍처를 재설계하지 마라.
