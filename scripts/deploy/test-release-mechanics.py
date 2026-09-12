#!/usr/bin/env python3
"""Isolated regression coverage for M6 release filesystem mechanics."""

import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
MECHANICS = ROOT / "scripts/deploy/release-mechanics.py"
VERIFIER = ROOT / "scripts/release/verify-release-bundle.sh"
A = "a" * 40
B = "b" * 40


def make_bundle(base: Path, sha: str, *, special: str | None = None) -> Path:
    bundle = base / f"bundle-{sha[:1]}-{special or 'normal'}"
    bundle.mkdir()
    (bundle / "backend.jar").write_bytes(f"backend-{sha}".encode())
    with tarfile.open(bundle / "frontend.tar.gz", "w:gz") as archive:
        for name, content in (("dist/index.html", sha.encode()), ("dist/assets/app.js", b"asset")):
            info = tarfile.TarInfo(name)
            info.size = len(content)
            archive.addfile(info, io.BytesIO(content))
        if special:
            info = tarfile.TarInfo("../escape" if special == "traversal" else f"dist/{special}")
            if special == "symlink":
                info.type, info.linkname = tarfile.SYMTYPE, "/etc/passwd"
            elif special == "hardlink":
                info.type, info.linkname = tarfile.LNKTYPE, "dist/index.html"
            elif special == "fifo":
                info.type = tarfile.FIFOTYPE
            archive.addfile(info)
    descriptors = {}
    for logical, filename in (("backend", "backend.jar"), ("frontend", "frontend.tar.gz")):
        payload = bundle / filename
        descriptors[logical] = {"file": filename, "sha256": hashlib.sha256(payload.read_bytes()).hexdigest(), "sizeBytes": payload.stat().st_size}
    manifest = {"schemaVersion": 1, "releaseFormat": "arp-release-v1", "sourceCommit": sha, **descriptors}
    (bundle / "release-manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    return bundle


def run(*arguments: str, success: bool = True) -> subprocess.CompletedProcess:
    result = subprocess.run(arguments, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if (result.returncode == 0) != success:
        raise AssertionError(f"unexpected exit {result.returncode}: {' '.join(arguments)}\n{result.stdout}\n{result.stderr}")
    return result


def command(action: str, *arguments: str, root: Path, success: bool = True) -> None:
    run("python3", str(MECHANICS), action, *arguments, "--root", str(root), success=success)


def state(root: Path, component: str) -> dict:
    return json.loads((root / f"opt/arp/release-state/{component}.json").read_text())


def pointer(root: Path, component: str) -> str:
    path = root / ("opt/arp/application.jar" if component == "backend" else "opt/arp/frontend/current")
    return Path(path.readlink()).parts[-2 if component == "backend" else -1]


with tempfile.TemporaryDirectory() as temporary:
    base = Path(temporary)
    runtime = base / "runtime"
    bundle_a, bundle_b = make_bundle(base, A), make_bundle(base, B)
    for sha, bundle in ((A, bundle_a), (B, bundle_b)):
        command("install", "backend", str(bundle), sha, root=runtime)
        command("install", "frontend", str(bundle), sha, root=runtime)
        command("activate", "backend", sha, root=runtime)
        command("activate", "frontend", sha, root=runtime)
    for component in ("backend", "frontend"):
        assert pointer(runtime, component) == B
        assert state(runtime, component) == {"current": B, "previous": A}
        command("rollback", component, root=runtime)
        assert pointer(runtime, component) == A
        assert state(runtime, component) == {"current": A, "previous": B}
    assert state(runtime, "backend")["current"] == state(runtime, "frontend")["current"]

    # A modified retained target cannot be activated and leaves the pointer unchanged.
    (runtime / f"opt/arp/releases/{B}/backend.jar").write_bytes(b"tampered")
    command("activate", "backend", B, root=runtime, success=False)
    assert pointer(runtime, "backend") == A

    # A modified extracted frontend cannot be activated.
    (runtime / f"opt/arp/frontend/releases/{B}/index.html").write_text("tampered")
    command("activate", "frontend", B, root=runtime, success=False)
    assert pointer(runtime, "frontend") == A

    tampered_bundle = base / "tampered-frontend-bundle"
    shutil.copytree(bundle_a, tampered_bundle)
    with (tampered_bundle / "frontend.tar.gz").open("ab") as archive:
        archive.write(b"tampered")
    command("install", "frontend", str(tampered_bundle), A, root=runtime, success=False)
    assert pointer(runtime, "frontend") == A

    command("install", "backend", str(bundle_a), B, root=base / "mismatch", success=False)
    command("rollback", "backend", root=base / "empty", success=False)

    # Removing the retained rollback target fails closed without changing the pointer.
    (runtime / f"opt/arp/releases/{B}/frontend.tar.gz").unlink()
    command("rollback", "frontend", root=runtime, success=False)
    assert pointer(runtime, "frontend") == A

    for kind in ("traversal", "symlink", "hardlink", "fifo"):
        unsafe = make_bundle(base, A, special=kind)
        run("bash", str(VERIFIER), str(unsafe), A, success=False)

print("M6 release install/activation/rollback regression passed")
