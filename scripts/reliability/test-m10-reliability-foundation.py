#!/usr/bin/env python3
from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, token: str, context: str) -> None:
    if token not in text:
        raise SystemExit(f"missing {context}: {token}")


driver = read("workload/k6/m10-normal.js")
runner = read("scripts/reliability/run-m10-control.sh")
prometheus = read("scripts/reliability/capture-m10-prometheus.py")
invariants = read("scripts/reliability/m10-db-invariants.sql")

for token in [
    "executor: 'constant-vus'",
    "const duration = __ENV.M10_DURATION || '5m';",
    "duration,",
    "exec: 'listDetail'",
    "vus: 12",
    "exec: 'createSave'",
    "vus: 4",
    "exec: 'submitResubmit'",
    "vus: 3",
    "exec: 'reviewerQueueDetail'",
    "vus: 6",
    "exec: 'reviewAction'",
    "exec: 'attachment'",
    "vus: 2",
    "new Counter(`m10_${family}_requests`)",
    "new Rate(`m10_${family}_errors`)",
    "new Trend(`m10_${family}_duration`, true)",
    "m10_non_file_errors",
    "milestone: 'm10'",
    "profile: 'normal-control'",
    "pace(started, 2.0)",
    "pace(started, 1.777778)",
    "pace(started, 1.0)",
    "pace(started, 2.666667)",
]:
    require(driver, token, "M10 normal driver")

vus = [int(value) for value in re.findall(r"\bvus:\s*(\d+)", driver)]
if sorted(vus) != [2, 3, 3, 4, 6, 12] or sum(vus) != 30:
    raise SystemExit(f"M10 control must retain W2 30-VU allocation: {vus!r}")

if "duration: '15m'" in driver:
    raise SystemExit("M10 control must not silently reuse the 15-minute W2 duration")
if "m8_" in driver:
    raise SystemExit("M10 driver must use M10 metric names")

for token in [
    "ARP_EXPECTED_SOURCE_SHA",
    "ARP_CONFIRM_M10_DATASET_RESET",
    "ARP_CONFIRM_M8_DATASET_RESET=yes",
    "ARP_M8_DATASET_PROFILE=M",
    "with-oslogin-ssh.py",
    "--ttl-seconds 1800",
    "output -json loadgen",
    "w2-interactive-overlay.sql",
    "k6/m10-normal.js",
    "M10_DURATION='5m'",
    "deploy/cloud-smoke.sh",
    "m10-db-invariants.sql",
    "capture-m10-prometheus.py",
    '"scenario": "m10-healthy-normal-control"',
    '"fault_injected": False',
    "M10_CONTROL_NON_FILE_SUCCESS_RATE",
    "M10_CONTROL_NON_FILE_P95_MS",
    "M10_CONTROL_TARGET",
    "PASS: M10 healthy control retained workload",
]:
    require(runner, token, "M10 control runner")

for forbidden in [
    "StrictHostKeyChecking=no",
    "systemctl stop",
    "systemctl kill",
    "kill -9",
    "pkill",
    "docker stop",
    "tofu apply",
    "gcloud compute instances stop",
    "-e APPLICANT_PASSWORD=",
    "-e REVIEWER_PASSWORD=",
]:
    if forbidden in runner:
        raise SystemExit(f"M10 healthy-control runner must not inject faults or weaken transport: {forbidden}")

for token in [
    "application_probe",
    "postgres_up",
    "hikari_active",
    "hikari_pending",
    "db_cpu_pct",
    "app_cpu_pct",
    "garage_up_by_node",
    "/api/v1/query_range",
]:
    require(prometheus, token, "M10 Prometheus capture")

for token in [
    "non_draft_latest_history_mismatch",
    "in_review_without_reviewer",
    "audit_subject_count_violation",
    "available_attachment_metadata_incomplete",
    "attachment_pending",
    "attachment_failed",
    "attachment_delete_pending",
]:
    require(invariants, token, "M10 database invariants")

subprocess.run(["node", "--check", str(ROOT / "workload/k6/m10-normal.js")], check=True)
subprocess.run(["bash", "-n", str(ROOT / "scripts/reliability/run-m10-control.sh")], check=True)
subprocess.run(
    ["python3", "-m", "py_compile", str(ROOT / "scripts/reliability/capture-m10-prometheus.py")],
    check=True,
)


r1_driver = read("workload/k6/m10-r1-process-failure.js")
r1_runner = read("scripts/reliability/run-m10-r1.sh")

for token in [
    "profile: 'r1-process-failure'",
    "exec: 'sessionContinuity'",
    "exec: 'publicApiProbe'",
    "exec: 'staticEdgeProbe'",
    "m10_r1_session_login_attempts",
    "M10_R1_SESSION_READY",
    "M10_R1_STATE|probe=",
    "sleep(0.25)",
]:
    require(r1_driver, token, "M10 R1 probe driver")

for token in [
    "systemctl kill --kill-who=main --signal=SIGKILL arp.service",
    "Restart=on-failure",
    "M10_R1_SYSTEMD_AUTO_RESTART=PASS",
    "M10_R1_PERSISTED_SESSION_RECOVERY=PASS",
    "M10_R1_STATIC_EDGE_OUTAGE=NOT_OBSERVED",
    "M10_R1_UNRELATED_DATA_SERVICES_HEALTHY=PASS",
    "deploy/cloud-smoke.sh",
    "m10-db-invariants.sql",
    "capture-m10-prometheus.py",
    '"scenario": "R1-application-process-failure"',
    '"fault_injected": True',
    "EMERGENCY_RECOVERY: arp.service is not active; starting it.",
]:
    require(r1_runner, token, "M10 R1 runner")

for forbidden in [
    "systemctl stop arp.service",
    "pkill",
    "kill -9",
    "tofu apply",
    "gcloud compute instances stop",
    "StrictHostKeyChecking=no",
]:
    if forbidden in r1_runner:
        raise SystemExit(f"M10 R1 runner must not contain: {forbidden}")

if r1_driver.count("sessionLoginAttempts.add(1)") != 1:
    raise SystemExit("R1 session probe must perform a single explicit login path")

subprocess.run(
    ["node", "--check", str(ROOT / "workload/k6/m10-r1-process-failure.js")],
    check=True,
)
subprocess.run(
    ["bash", "-n", str(ROOT / "scripts/reliability/run-m10-r1.sh")],
    check=True,
)


r2_driver = read("workload/k6/m10-r2-postgresql-outage.js")
r2_runner = read("scripts/reliability/run-m10-r2.sh")

for token in [
    "profile: 'r2-postgresql-outage'",
    "exec: 'listDetail'",
    "vus: 12",
    "exec: 'createSave'",
    "vus: 4",
    "exec: 'submitResubmit'",
    "vus: 3",
    "exec: 'reviewerQueueDetail'",
    "vus: 6",
    "exec: 'reviewAction'",
    "exec: 'attachment'",
    "vus: 2",
    "exec: 'persistedSessionProbe'",
    "exec: 'publicApiProbe'",
    "exec: 'staticEdgeProbe'",
    "new Counter(`m10_r2_${family}_attempts`)",
    "m10_r2_session_login_attempts",
    "M10_R2_SESSION_READY",
    "M10_R2_STATE|probe=",
    "pace(started, 2.0)",
    "pace(started, 1.777778)",
    "pace(started, 1.0)",
    "pace(started, 2.666667)",
]:
    require(r2_driver, token, "M10 R2 driver")

for token in [
    "ARP_CONFIRM_M10_DATASET_RESET",
    "ARP_CONFIRM_M8_DATASET_RESET=yes",
    "ARP_M8_DATASET_PROFILE=M",
    "w2-interactive-overlay.sql",
    "M10_DURATION='5m'",
    "systemctl stop postgresql@16-main.service",
    "systemctl start postgresql@16-main.service",
    "hold bounded PostgreSQL outage for 60 seconds",
    "sleep 60",
    "M10_R2_BUSINESS_ATTEMPTS",
    "M10_R2_DB_RESTORE=PASS",
    "M10_R2_APPLICATION_RECOVERED_WITHOUT_RESTART=PASS",
    "M10_R2_STATIC_EDGE_OUTAGE=NOT_OBSERVED",
    "M10_R2_TELEMETRY_BLAST_RADIUS=PASS",
    "deploy/cloud-smoke.sh",
    "m10-db-invariants.sql",
    "capture-m10-prometheus.py",
    '"scenario": "R2-postgresql-outage"',
    '"fault_injected": True',
    "5m; intentionally not exercised by this bounded 60s outage",
    "EMERGENCY_RECOVERY: PostgreSQL cluster unit may still be stopped; starting it.",
]:
    require(r2_runner, token, "M10 R2 runner")

for forbidden in [
    "systemctl stop postgresql.service",
    "systemctl stop arp.service",
    "systemctl kill",
    "kill -9",
    "pkill",
    "gcloud compute instances stop",
    "tofu apply",
    "StrictHostKeyChecking=no",
    "sleep 300",
]:
    if forbidden in r2_runner:
        raise SystemExit(f"M10 R2 runner must not contain: {forbidden}")

subprocess.run(
    ["node", "--check", str(ROOT / "workload/k6/m10-r2-postgresql-outage.js")],
    check=True,
)
subprocess.run(
    ["bash", "-n", str(ROOT / "scripts/reliability/run-m10-r2.sh")],
    check=True,
)


r3a_driver = read("workload/k6/m10-r3a-garage-non-endpoint.js")
r3a_runner = read("scripts/reliability/run-m10-r3a.sh")

for token in [
    "profile: 'r3a-garage-non-endpoint'",
    "exec: 'attachmentContinuity'",
    "exec: 'nonAttachmentContinuity'",
    "m10_r3a_attachment_attempts",
    "m10_r3a_attachment_upload_errors",
    "m10_r3a_attachment_download_errors",
    "m10_r3a_attachment_delete_errors",
    "m10_r3a_non_attachment_errors",
    "M10_R3A_ATTACHMENT_OK",
    "M10_R3A_NON_ATTACHMENT_OK",
]:
    require(r3a_driver, token, "M10 R3a driver")

for token in [
    "ARP_CONFIRM_M10_DATASET_RESET",
    "ARP_CONFIRM_M8_DATASET_RESET=yes",
    "ARP_M8_DATASET_PROFILE=M",
    "w2-interactive-overlay.sql",
    "GARAGE_ENDPOINT",
    "http://10.40.0.41:3900",
    "storage-02",
    "docker stop --time 10 garage",
    "docker start garage",
    "hold bounded non-endpoint node outage for 60 seconds",
    "M10_R3A_STORAGE02_REMOVED_FROM_HEALTHY_SET=PASS",
    "M10_R3A_HYPOTHESIS=",
    "M10_R3A_TELEMETRY_NODE_ISOLATION=PASS",
    "M10_R3A_APPLICATION_STABLE=PASS",
    "deploy/cloud-smoke.sh",
    "m10-db-invariants.sql",
    "db-invariants-during-fault.txt",
    "capture-m10-prometheus.py",
    '"scenario": "R3a-garage-non-endpoint-node-loss"',
    '"fault_injected": True',
    "EMERGENCY_RECOVERY: storage-02 Garage may still be stopped; starting it.",
]:
    require(r3a_runner, token, "M10 R3a runner")

for forbidden in [
    "docker stop garage && docker stop",
    "systemctl stop arp.service",
    "systemctl stop postgresql",
    "gcloud compute instances stop",
    "tofu apply",
    "StrictHostKeyChecking=no",
]:
    if forbidden in r3a_runner:
        raise SystemExit(f"M10 R3a runner must not contain: {forbidden}")

subprocess.run(
    ["node", "--check", str(ROOT / "workload/k6/m10-r3a-garage-non-endpoint.js")],
    check=True,
)
subprocess.run(
    ["bash", "-n", str(ROOT / "scripts/reliability/run-m10-r3a.sh")],
    check=True,
)

print("M10 reliability foundation and R1/R2/R3a contracts: PASS")
