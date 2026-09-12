#!/usr/bin/env python3
"""Install, activate, and roll back verified M6 release bundles."""

import argparse
import filecmp
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile
from typing import NoReturn

SHA_PATTERN = re.compile(r"[0-9a-f]{40}")
COMPONENTS = ("backend", "frontend")


def fail(message: str) -> NoReturn:
    raise SystemExit(message)


def require_sha(value: str) -> str:
    if not SHA_PATTERN.fullmatch(value):
        fail("release identity must be a full lowercase 40-character Git SHA")
    return value


def runtime_path(root: Path, absolute: str) -> Path:
    return root / absolute.lstrip("/")


def verifier() -> Path:
    return Path(__file__).resolve().parents[1] / "release" / "verify-release-bundle.sh"


def verify_bundle(bundle: Path, sha: str) -> None:
    subprocess.run(["bash", str(verifier()), str(bundle), sha], check=True)


def identical(left: Path, right: Path) -> bool:
    return left.is_file() and not left.is_symlink() and filecmp.cmp(left, right, shallow=False)


def install_file(source: Path, target: Path) -> None:
    if target.exists() or target.is_symlink():
        if identical(source, target):
            return
        fail(f"refusing to overwrite retained release file with different content: {target}")
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=target.parent, prefix=f".{target.name}.", delete=False) as output:
        temporary = Path(output.name)
        with source.open("rb") as input_file:
            shutil.copyfileobj(input_file, output)
    os.chmod(temporary, 0o644)
    try:
        os.link(temporary, target)
    except FileExistsError:
        if not identical(source, target):
            fail(f"concurrent install produced different content: {target}")
    finally:
        temporary.unlink(missing_ok=True)


def same_tree(left: Path, right: Path) -> bool:
    def inventory(base: Path) -> dict[str, tuple[str, str | None]]:
        result = {}
        for path in sorted(base.rglob("*")):
            relative = path.relative_to(base).as_posix()
            if path.is_symlink():
                result[relative] = ("unsafe", None)
            elif path.is_dir():
                result[relative] = ("directory", None)
            elif path.is_file():
                result[relative] = ("file", hashlib.sha256(path.read_bytes()).hexdigest())
            else:
                result[relative] = ("unsafe", None)
        return result
    return left.is_dir() and inventory(left) == inventory(right)


def extracted_frontend(bundle: Path, destination: Path) -> Path:
    # The bundle verifier has already rejected links and special/path-traversal entries.
    with tarfile.open(bundle / "frontend.tar.gz", mode="r:gz") as archive:
        archive.extractall(destination, filter="data")
    return destination / "dist"


def install(args: argparse.Namespace) -> None:
    sha = require_sha(args.sha)
    bundle = Path(args.bundle).resolve()
    verify_bundle(bundle, sha)
    root = Path(args.root).resolve()
    retained = runtime_path(root, f"/opt/arp/releases/{sha}")
    retained.mkdir(parents=True, exist_ok=True)
    for name in ("backend.jar", "frontend.tar.gz", "release-manifest.json"):
        install_file(bundle / name, retained / name)
    verify_bundle(retained, sha)

    if args.component == "frontend":
        target = runtime_path(root, f"/opt/arp/frontend/releases/{sha}")
        target.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=target.parent, prefix=f".{sha}.") as temporary:
            staged = extracted_frontend(retained, Path(temporary))
            if target.exists() or target.is_symlink():
                if not same_tree(staged, target):
                    fail(f"refusing to overwrite frontend release with different content: {target}")
            else:
                os.rename(staged, target)


def release_paths(root: Path, component: str, sha: str) -> tuple[Path, Path]:
    if component == "backend":
        return (
            runtime_path(root, f"/opt/arp/releases/{sha}/backend.jar"),
            runtime_path(root, "/opt/arp/application.jar"),
        )
    return (
        runtime_path(root, f"/opt/arp/frontend/releases/{sha}"),
        runtime_path(root, "/opt/arp/frontend/current"),
    )


def verify_installed(root: Path, component: str, sha: str) -> Path:
    retained = runtime_path(root, f"/opt/arp/releases/{sha}")
    verify_bundle(retained, sha)
    target, _ = release_paths(root, component, sha)
    if component == "backend":
        if not identical(retained / "backend.jar", target):
            fail(f"backend release target failed verification: {target}")
    else:
        with tempfile.TemporaryDirectory() as temporary:
            expected = extracted_frontend(retained, Path(temporary))
            if not same_tree(expected, target):
                fail(f"frontend release target failed verification: {target}")
    return target


def read_state(root: Path, component: str) -> dict:
    path = runtime_path(root, f"/opt/arp/release-state/{component}.json")
    if not path.exists():
        return {"current": None, "previous": None}
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"invalid {component} release state: {exc}")
    if set(state) != {"current", "previous"}:
        fail(f"invalid {component} release state fields")
    for value in state.values():
        if value is not None:
            require_sha(value)
    return state


def atomic_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.parent / f".{path.name}.{os.getpid()}"
    temporary.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def switch(root: Path, component: str, sha: str, previous: str | None) -> None:
    target = verify_installed(root, component, sha)
    _, pointer = release_paths(root, component, sha)
    pointer.parent.mkdir(parents=True, exist_ok=True)
    temporary = pointer.parent / f".{pointer.name}.{os.getpid()}"
    temporary.unlink(missing_ok=True)
    temporary.symlink_to(target)
    os.replace(temporary, pointer)
    atomic_json(
        runtime_path(root, f"/opt/arp/release-state/{component}.json"),
        {"current": sha, "previous": previous},
    )


def activate(args: argparse.Namespace) -> None:
    sha = require_sha(args.sha)
    root = Path(args.root).resolve()
    state = read_state(root, args.component)
    previous = state["current"] if state["current"] != sha else state["previous"]
    switch(root, args.component, sha, previous)


def rollback(args: argparse.Namespace) -> None:
    target_sha = require_sha(args.sha)
    root = Path(args.root).resolve()
    state = read_state(root, args.component)
    if state["current"] is None or state["previous"] is None:
        fail(f"no previous {args.component} release is available for rollback")
    if target_sha != state["previous"]:
        fail(f"requested {args.component} rollback target is not the recorded previous release")
    switch(root, args.component, target_sha, state["current"])


def verify_installed_command(args: argparse.Namespace) -> None:
    verify_installed(Path(args.root).resolve(), args.component, require_sha(args.sha))


def verify_rollback(args: argparse.Namespace) -> None:
    target_sha = require_sha(args.sha)
    root = Path(args.root).resolve()
    state = read_state(root, args.component)
    if state["current"] is None or state["previous"] is None:
        fail(f"no previous {args.component} release is available for rollback")
    if target_sha != state["previous"]:
        fail(f"requested {args.component} rollback target is not the recorded previous release")
    verify_installed(root, args.component, target_sha)


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser()
    subparsers = result.add_subparsers(dest="command", required=True)
    install_parser = subparsers.add_parser("install")
    install_parser.add_argument("component", choices=COMPONENTS)
    install_parser.add_argument("bundle")
    install_parser.add_argument("sha")
    install_parser.add_argument("--root", default="/")
    install_parser.set_defaults(action=install)
    activate_parser = subparsers.add_parser("activate")
    activate_parser.add_argument("component", choices=COMPONENTS)
    activate_parser.add_argument("sha")
    activate_parser.add_argument("--root", default="/")
    activate_parser.set_defaults(action=activate)
    verify_parser = subparsers.add_parser("verify-installed")
    verify_parser.add_argument("component", choices=COMPONENTS)
    verify_parser.add_argument("sha")
    verify_parser.add_argument("--root", default="/")
    verify_parser.set_defaults(action=verify_installed_command)
    rollback_verify_parser = subparsers.add_parser("verify-rollback")
    rollback_verify_parser.add_argument("component", choices=COMPONENTS)
    rollback_verify_parser.add_argument("sha")
    rollback_verify_parser.add_argument("--root", default="/")
    rollback_verify_parser.set_defaults(action=verify_rollback)
    rollback_parser = subparsers.add_parser("rollback")
    rollback_parser.add_argument("component", choices=COMPONENTS)
    rollback_parser.add_argument("sha")
    rollback_parser.add_argument("--root", default="/")
    rollback_parser.set_defaults(action=rollback)
    return result


def main() -> None:
    args = parser().parse_args()
    args.action(args)


if __name__ == "__main__":
    main()
