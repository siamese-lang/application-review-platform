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
    "release_publish",
)

FULL_REGRESSION_PATHS = {
    ".github/workflows/baseline-ci.yml",
    "scripts/ci/classify-baseline-ci.py",
}


def matches(path: str, patterns: Iterable[str]) -> bool:
    return any(fnmatch.fnmatch(path, pattern) for pattern in patterns)


def any_match(paths: set[str], patterns: Iterable[str]) -> bool:
    return any(matches(path, patterns) for path in paths)


def classify(paths: set[str], *, force_full: bool = False) -> dict[str, bool]:
    full = force_full or bool(paths & FULL_REGRESSION_PATHS)

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
            "deploy/check-prerequisites.sh",
            "deploy/tofu-bootstrap-plan.sh",
            "deploy/tofu-init-plan.sh",
            "scripts/deploy/test-delivery-identity-contract.sh",
            "scripts/deploy/test-m11-backup-foundation.py",
            "scripts/backup/**",
            "scripts/restore/**",
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
    assert m11_backup["m4_infrastructure_static"]
    assert not m11_backup["release_publish"]

    full = classify({".github/workflows/baseline-ci.yml"})
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
