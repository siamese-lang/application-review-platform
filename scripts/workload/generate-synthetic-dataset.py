#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from synthetic_dataset import generate_dataset, load_profiles


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate deterministic M8 synthetic dataset bundles.")
    parser.add_argument("--profile", choices=("S", "M", "L"), required=True)
    parser.add_argument("--seed", type=int, default=20260914)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[2]
    profiles = load_profiles(root / "workload/datasets/profiles.json")
    manifest = generate_dataset(args.output, profiles[args.profile], args.seed)
    counts = manifest["counts"]
    print(
        "M8_DATASET_GENERATED "
        f"profile={args.profile} seed={args.seed} "
        f"applications={counts['applications']} "
        f"histories={counts['application_status_history']}"
    )


if __name__ == "__main__":
    main()
