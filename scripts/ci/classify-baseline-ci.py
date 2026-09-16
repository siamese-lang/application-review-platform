#!/usr/bin/env python3
from __future__ import annotations

import argparse
import fnmatch
import os
import sys
from collections.abc import Iterable

OUTPUTS = (
    "m1_application",
    "m4_infrastructure_static",
    "m5_frontend",
    "m5_browser_e2e",
    "m5_nginx_routing",
    "m6_phase4a_repository_preflight",
    "m6_delivery_workflow_static",
    "m6_release_bundle",
    "m6_release_install",
    "m7_observability_infrastructure_static",
    "m8_workload_foundation_static",
    "m8_dataset_tooling_static",
    "m10_reliability_static",
    "m11_backup_static",
    "m11_recovery_static",
    "release_publish",
)

def matches(path: str, patterns: Iterable[str]) -> bool:
    return any(fnmatch.fnmatch(path, pattern) for pattern in patterns)


def any_match(paths: set[str], patterns: Iterable[str]) -> bool:
    return any(matches(path, patterns) for path in paths)


def classify(paths: set[str], *, force_full: bool = False) -> dict[str, bool]:
    full = force_full

    backend = any_match(
        paths,
        (
            "app/**",
            "pom.xml",
            ".mvn/**",
            "mvnw",
            "scripts/start-test-garage.sh",
        ),
    )
    frontend = any_match(paths, ("frontend/**",))
    release_material = any_match(
        paths,
        (
            "app/**",
            "frontend/**",
            "pom.xml",
            ".mvn/**",
            "mvnw",
            "scripts/release/**",
        ),
    )
    product_integration = backend or frontend or any_match(
        paths,
        (
            "scripts/start-test-garage.sh",
            "scripts/verify-m5-nginx-routing.sh",
            "config/nginx/**",
        ),
    )
    product_suite = product_integration or release_material

    dataset_core = any_match(
        paths,
        (
            "scripts/workload/synthetic_dataset.py",
            "scripts/workload/generate-synthetic-dataset.py",
            "workload/datasets/**",
        ),
    )
    m8_dataset = any_match(
        paths,
        (
            "scripts/workload/**",
            "workload/datasets/**",
            "deploy/load-m8-dataset.sh",
        ),
    )
    m10_reliability = any_match(
        paths,
        (
            "scripts/reliability/**",
            "workload/k6/m10-normal.js",
            "docs/plans/active/M10-reliability.md",
        ),
    )

    m8_workload = any_match(
        paths,
        (
            "workload/**",
            "scripts/workload/test-m8-workload-foundation.py",
            "scripts/workload/test-m8-loadgen-config.py",
            "deploy/m8-loadgen-preflight.sh",
            "deploy/configure-loadgen.sh",
            "config/ansible/loadgen.yml",
            "config/ansible/roles/loadgen/**",
            "infra/opentofu/**",
        ),
    )

    infrastructure = any_match(
        paths,
        (
            "infra/opentofu/**",
            "config/ansible/**",
            "deploy/generate-inventory.py",
            "deploy/with-oslogin-ssh.py",
            "deploy/build-and-configure.sh",
            "deploy/bootstrap-garage.sh",
            "deploy/configure-m11-full-dr-foundation.sh",
            "deploy/restore-m11-full-dr-garage.sh",
            "deploy/bootstrap-m11-full-dr-ip-tls.sh",
            "scripts/deploy/test-m11-full-dr-https.py",
            "config/ansible/full-dr-edge-https.yml",
            "deploy/check-prerequisites.sh",
            "deploy/tofu-bootstrap-plan.sh",
            "deploy/tofu-init-plan.sh",
            "scripts/deploy/test-delivery-identity-contract.sh",
            "scripts/deploy/test-m11-backup-foundation.py",
            "scripts/deploy/test-m11-full-dr-infrastructure.py",
            "scripts/deploy/test-m11-full-dr-foundation.py",
            "scripts/deploy/test-m11-full-dr-garage-restore.py",
            "config/ansible/full-dr-garage-restore.yml",
        ),
    )

    m11_backup = any_match(
        paths,
        (
            "scripts/backup/**",
            "scripts/deploy/test-m11-checkpoint-foundation.py",
            "scripts/deploy/test-m11-backup-closeout.py",
            "deploy/closeout-m11-backup.sh",
            "config/ansible/m11-backup-closeout.yml",
        ),
    )

    m11_recovery = any_match(
        paths,
        (
            "scripts/restore/**",
            "scripts/deploy/test-m11-pitr-execution.py",
            "scripts/deploy/test-m11-full-dr-foundation.py",
            "scripts/deploy/test-m11-full-dr-garage-restore.py",
            "deploy/restore-m11-full-dr-garage.sh",
            "deploy/deploy-m11-full-dr-release.sh",
            "deploy/bootstrap-m11-full-dr-ip-tls.sh",
            "scripts/deploy/test-m11-full-dr-https.py",
            "scripts/deploy/test-m11-full-dr-integrity.py",
            "scripts/deploy/test-m11-full-dr-release.py",
            "deploy/verify-m11-full-dr-integrity.sh",
            "config/ansible/full-dr-garage-restore.yml",
            "config/ansible/full-dr-integrity.yml",
        ),
    )

    m6_preflight = any_match(
        paths,
        (
            "scripts/deploy/test-m6-phase4a-contract.py",
            "deploy/m6-runtime-preflight.sh",
            "deploy/tofu-bootstrap-plan.sh",
            "deploy/tofu-init-plan.sh",
            "deploy/bootstrap-synthetic-users.sh",
            "deploy/prepare-secrets.sh",
        ),
    )
    m6_delivery = any_match(
        paths,
        (
            ".github/workflows/deploy-release.yml",
            "scripts/deploy/test-delivery-workflow-contract.py",
            "scripts/deploy/stage-release-on-ops.sh",
            "scripts/deploy/test-stage-release-on-ops.sh",
        ),
    )
    m6_release = release_material or any_match(
        paths,
        (
            "scripts/deploy/test-release-mechanics.py",
            "scripts/deploy/test-release-runtime-contract.sh",
            "config/ansible/release.yml",
            "config/ansible/rollback.yml",
            "config/ansible/roles/release_runtime/**",
            "config/ansible/roles/rollback/**",
        ),
    )

    m7_observability = any_match(
        paths,
        (
            "scripts/deploy/test-m7-observability-infrastructure.sh",
            "config/ansible/site.yml",
            "config/ansible/group_vars/**",
            "config/ansible/roles/observability/**",
            "config/ansible/roles/alloy/**",
            "config/ansible/roles/prometheus/**",
            "config/ansible/roles/loki/**",
            "config/ansible/roles/tempo/**",
            "config/ansible/roles/grafana/**",
            "config/ansible/roles/alertmanager/**",
        ),
    )

    flags = {
        "m1_application": backend or dataset_core or product_suite,
        "m4_infrastructure_static": infrastructure,
        "m5_frontend": product_suite,
        "m5_browser_e2e": product_suite,
        "m5_nginx_routing": product_suite,
        "m6_phase4a_repository_preflight": m6_preflight,
        "m6_delivery_workflow_static": m6_delivery,
        "m6_release_bundle": release_material,
        "m6_release_install": m6_release,
        "m7_observability_infrastructure_static": m7_observability,
        "m8_workload_foundation_static": m8_workload,
        "m8_dataset_tooling_static": m8_dataset,
        "m10_reliability_static": m10_reliability,
        "m11_backup_static": m11_backup,
        "m11_recovery_static": m11_recovery,
        "release_publish": release_material,
    }

    if full:
        full_flags = {key: True for key in OUTPUTS}
        full_flags["release_publish"] = release_material
        return full_flags
    return flags


def self_test() -> None:
    docs = classify({"docs/AI_PROJECT_STATE.md"})
    assert not any(docs.values())

    m8_live = classify(
        {
            "deploy/load-m8-dataset.sh",
            "scripts/workload/test-m8-live-dataset-load.py",
        }
    )
    assert m8_live["m8_dataset_tooling_static"]
    assert not m8_live["m5_browser_e2e"]
    assert not m8_live["m4_infrastructure_static"]
    assert not m8_live["release_publish"]

    m10 = classify({"scripts/reliability/run-m10-control.sh"})
    assert m10["m10_reliability_static"]
    assert not m10["release_publish"]

    frontend = classify({"frontend/src/App.tsx"})
    for key in (
        "m1_application",
        "m5_frontend",
        "m5_browser_e2e",
        "m5_nginx_routing",
        "m6_release_bundle",
        "m6_release_install",
        "release_publish",
    ):
        assert frontend[key], key
    assert not frontend["m4_infrastructure_static"]

    infra = classify({"infra/opentofu/compute.tf"})
    assert infra["m4_infrastructure_static"]
    assert infra["m8_workload_foundation_static"]
    assert not infra["release_publish"]

    m11_backup = classify({"scripts/backup/garage_object_backup.py"})
    assert m11_backup["m11_backup_static"]
    assert not m11_backup["m4_infrastructure_static"]
    assert not m11_backup["m11_recovery_static"]
    assert not m11_backup["release_publish"]

    m11_checkpoint = classify({"scripts/backup/run-m11-mutation-gate.sh"})
    assert m11_checkpoint["m11_backup_static"]
    assert not m11_checkpoint["m4_infrastructure_static"]

    m11_backup_closeout = classify({"deploy/closeout-m11-backup.sh"})
    assert m11_backup_closeout["m11_backup_static"]
    assert not m11_backup_closeout["release_publish"]

    m11_restore = classify({"scripts/restore/run-m11-pitr-restore.sh"})
    assert m11_restore["m11_recovery_static"]
    assert not m11_restore["m4_infrastructure_static"]
    assert not m11_restore["m1_application"]
    assert not m11_restore["release_publish"]

    m11_restore_contract = classify({"scripts/deploy/test-m11-pitr-execution.py"})
    assert m11_restore_contract["m11_recovery_static"]
    assert not m11_restore_contract["m4_infrastructure_static"]

    m11_full_dr_infra = classify({"scripts/deploy/test-m11-full-dr-infrastructure.py"})
    assert m11_full_dr_infra["m4_infrastructure_static"]
    assert not m11_full_dr_infra["release_publish"]

    m11_full_dr_foundation = classify({"scripts/deploy/test-m11-full-dr-foundation.py"})
    assert m11_full_dr_foundation["m4_infrastructure_static"]
    assert m11_full_dr_foundation["m11_recovery_static"]
    assert not m11_full_dr_foundation["release_publish"]

    m11_full_dr_garage = classify({"scripts/deploy/test-m11-full-dr-garage-restore.py"})
    assert m11_full_dr_garage["m4_infrastructure_static"]
    assert m11_full_dr_garage["m11_recovery_static"]
    assert not m11_full_dr_garage["release_publish"]

    m11_full_dr_release = classify({"scripts/deploy/test-m11-full-dr-release.py"})
    assert m11_full_dr_release["m11_recovery_static"]
    assert not m11_full_dr_release["m4_infrastructure_static"]
    assert not m11_full_dr_release["release_publish"]

    m11_full_dr_https = classify({"scripts/deploy/test-m11-full-dr-https.py"})
    assert m11_full_dr_https["m4_infrastructure_static"]
    assert m11_full_dr_https["m11_recovery_static"]
    assert not m11_full_dr_https["release_publish"]

    m11_full_dr_integrity = classify({"scripts/deploy/test-m11-full-dr-integrity.py"})
    assert m11_full_dr_integrity["m11_recovery_static"]
    assert not m11_full_dr_integrity["m4_infrastructure_static"]
    assert not m11_full_dr_integrity["release_publish"]

    ci_config = classify({
        ".github/workflows/baseline-ci.yml",
        "scripts/ci/classify-baseline-ci.py",
    })
    assert not any(ci_config.values())

    full = classify(set(), force_full=True)
    assert all(value for key, value in full.items() if key != "release_publish")
    assert not full["release_publish"]

    print("baseline CI changed-path classifier: PASS")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force-full", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return

    paths = {line.strip() for line in sys.stdin if line.strip()}
    result = classify(paths, force_full=args.force_full)

    output_path = os.environ.get("GITHUB_OUTPUT")
    lines = [f"{key}={'true' if result[key] else 'false'}" for key in OUTPUTS]
    if output_path:
        with open(output_path, "a", encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")
    else:
        print("\n".join(lines))


if __name__ == "__main__":
    main()
