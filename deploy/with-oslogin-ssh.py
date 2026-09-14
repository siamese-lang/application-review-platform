#!/usr/bin/env python3
"""Run a command with an ephemeral OS Login SSH identity from ops-01.

The private key and known_hosts file exist only for the lifetime of the child
command. The public key is registered through the OS Login API with a short
expiry and is deleted best-effort when the command exits. Host keys are read
from Compute Engine guest attributes over the authenticated Google API.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
from typing import Any
from urllib import error, parse, request

METADATA_BASE = "http://metadata.google.internal/computeMetadata/v1"
OSLOGIN_BASE = "https://oslogin.googleapis.com/v1"
COMPUTE_BASE = "https://compute.googleapis.com/compute/v1"
DEFAULT_TTL_SECONDS = 900
HOST_KEY_ATTEMPTS = 12
HOST_KEY_RETRY_SECONDS = 5
KEY_PROPAGATION_SECONDS = 5


class ApiError(RuntimeError):
    def __init__(self, status: int, url: str):
        super().__init__(f"Google API request failed with HTTP {status}: {url}")
        self.status = status


def metadata_text(path: str) -> str:
    req = request.Request(
        f"{METADATA_BASE}/{path}",
        headers={"Metadata-Flavor": "Google"},
    )
    try:
        with request.urlopen(req, timeout=5) as response:
            return response.read().decode("utf-8").strip()
    except error.URLError as exc:
        raise RuntimeError(
            "Metadata server is unavailable; run this helper on ops-01."
        ) from exc


def google_json(
    url: str,
    access_token: str,
    *,
    method: str = "GET",
    payload: dict[str, Any] | None = None,
) -> dict[str, Any]:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"Authorization": f"Bearer {access_token}"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    req = request.Request(url, data=body, headers=headers, method=method)
    try:
        with request.urlopen(req, timeout=15) as response:
            data = response.read()
    except error.HTTPError as exc:
        raise ApiError(exc.code, url) from None
    if not data:
        return {}
    return json.loads(data.decode("utf-8"))


def tofu_output_prefix() -> list[str]:
    """Read the root-owned runtime state without running the whole deployment as root."""
    if os.geteuid() == 0:
        return ["tofu"]
    return ["sudo", "-n", "tofu"]


def runtime_ssh_inventory(repo_root: Path) -> dict[str, dict[str, str]]:
    result = subprocess.run(
        tofu_output_prefix()
        + [
            f"-chdir={repo_root / 'infra' / 'opentofu'}",
            "output",
            "-json",
            "ssh_inventory",
        ],
        check=True,
        text=True,
        capture_output=True,
    )
    inventory = json.loads(result.stdout)
    if not isinstance(inventory, dict) or not inventory:
        raise RuntimeError("OpenTofu SSH inventory output is empty.")
    return inventory


def register_ephemeral_key(
    service_account_email: str,
    project_id: str,
    public_key: str,
    access_token: str,
    ttl_seconds: int,
) -> tuple[str, str | None]:
    user = parse.quote(service_account_email, safe="@._-")
    query = parse.urlencode({"projectId": project_id})
    expires = str(int((time.time() + ttl_seconds) * 1_000_000))
    imported = google_json(
        f"{OSLOGIN_BASE}/users/{user}:importSshPublicKey?{query}",
        access_token,
        method="POST",
        payload={"key": public_key, "expirationTimeUsec": expires},
    )

    profile = google_json(
        f"{OSLOGIN_BASE}/users/{user}/loginProfile?{query}",
        access_token,
    )
    accounts = profile.get("posixAccounts", [])
    if not accounts:
        raise RuntimeError("OS Login returned no POSIX account for ops-01 identity.")
    primary = next(
        (
            account
            for account in accounts
            if account.get("projectId") == project_id and account.get("primary")
        ),
        next(
            (account for account in accounts if account.get("projectId") == project_id),
            accounts[0],
        ),
    )
    username = primary.get("username")
    if not username:
        raise RuntimeError("OS Login POSIX account has no username.")

    key_resource = None
    ssh_keys = imported.get("loginProfile", {}).get("sshPublicKeys", {})
    for key_info in ssh_keys.values():
        if key_info.get("key", "").strip() == public_key.strip():
            key_resource = key_info.get("name")
            break
    return username, key_resource


def fetch_host_keys(
    project_id: str,
    inventory: dict[str, dict[str, str]],
    access_token: str,
) -> list[str]:
    known_hosts: list[str] = []
    for name, node in sorted(inventory.items()):
        zone = node["zone"]
        private_ip = node["private_ip"]
        query = parse.urlencode({"queryPath": "hostkeys/"})
        url = (
            f"{COMPUTE_BASE}/projects/{parse.quote(project_id, safe='')}"
            f"/zones/{parse.quote(zone, safe='')}"
            f"/instances/{parse.quote(name, safe='')}"
            f"/getGuestAttributes?{query}"
        )

        response: dict[str, Any] | None = None
        for attempt in range(HOST_KEY_ATTEMPTS):
            try:
                candidate = google_json(url, access_token)
                items = candidate.get("queryValue", {}).get("items", [])
                if items:
                    response = candidate
                    break
            except ApiError as exc:
                if exc.status in (401, 403):
                    raise
            if attempt + 1 < HOST_KEY_ATTEMPTS:
                time.sleep(HOST_KEY_RETRY_SECONDS)

        if response is None:
            raise RuntimeError(
                f"No trusted guest-attribute SSH host keys were available for {name}."
            )

        fqdn = f"{name}.{zone}.c.{project_id}.internal"
        host_aliases = f"{name},{private_ip},{fqdn}"
        for item in response.get("queryValue", {}).get("items", []):
            key_type = item.get("key", "")
            key_value = item.get("value", "")
            if key_type.startswith(("ssh-", "ecdsa-sha2-")) and key_value:
                known_hosts.append(f"{host_aliases} {key_type} {key_value}")

    if not known_hosts:
        raise RuntimeError("No SSH host keys were returned for the runtime SSH inventory.")
    return known_hosts


def delete_ephemeral_key(
    key_resource: str | None,
    access_token: str,
) -> None:
    if not key_resource:
        return
    resource = parse.quote(key_resource, safe="/:@._-")
    try:
        google_json(f"{OSLOGIN_BASE}/{resource}", access_token, method="DELETE")
    except Exception as exc:
        print(
            f"Warning: could not delete temporary OS Login public key immediately: {exc}",
            file=sys.stderr,
        )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run a command with short-lived OS Login SSH credentials from ops-01."
    )
    parser.add_argument(
        "--ttl-seconds",
        type=int,
        default=DEFAULT_TTL_SECONDS,
        help="OS Login public-key lifetime (default: 900 seconds).",
    )
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()

    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        parser.error("a command is required after --")
    if not 60 <= args.ttl_seconds <= 3600:
        parser.error("--ttl-seconds must be between 60 and 3600")

    repo_root = Path(__file__).resolve().parents[1]
    project_id = metadata_text("project/project-id")
    service_account_email = metadata_text("instance/service-accounts/default/email")
    expected_email = f"arp-m4-ops@{project_id}.iam.gserviceaccount.com"
    if service_account_email != expected_email:
        raise RuntimeError(
            f"This helper must run as the M4 ops service account ({expected_email})."
        )
    token_payload = json.loads(metadata_text("instance/service-accounts/default/token"))
    access_token = token_payload["access_token"]
    inventory = runtime_ssh_inventory(repo_root)

    key_resource: str | None = None
    with tempfile.TemporaryDirectory(prefix="arp-oslogin-") as temp_dir:
        temp_path = Path(temp_dir)
        private_key = temp_path / "id_ed25519"
        known_hosts = temp_path / "known_hosts"

        subprocess.run(
            [
                "ssh-keygen",
                "-q",
                "-t",
                "ed25519",
                "-N",
                "",
                "-C",
                f"arp-ops-ephemeral-{int(time.time())}",
                "-f",
                str(private_key),
            ],
            check=True,
        )
        public_key = private_key.with_suffix(".pub").read_text().strip()

        try:
            username, key_resource = register_ephemeral_key(
                service_account_email,
                project_id,
                public_key,
                access_token,
                args.ttl_seconds,
            )
            time.sleep(KEY_PROPAGATION_SECONDS)
            known_hosts.write_text(
                "\n".join(fetch_host_keys(project_id, inventory, access_token)) + "\n"
            )
            os.chmod(private_key, 0o600)
            os.chmod(known_hosts, 0o600)

            env = os.environ.copy()
            env.update(
                {
                    "ARP_OSLOGIN_USER": username,
                    "ARP_OSLOGIN_SSH_KEY": str(private_key),
                    "ARP_OSLOGIN_KNOWN_HOSTS": str(known_hosts),
                    "ANSIBLE_REMOTE_USER": username,
                    "ANSIBLE_PRIVATE_KEY_FILE": str(private_key),
                    "ANSIBLE_HOST_KEY_CHECKING": "True",
                    "ANSIBLE_SSH_COMMON_ARGS": (
                        f"-o UserKnownHostsFile={known_hosts} "
                        "-o StrictHostKeyChecking=yes -o IdentitiesOnly=yes"
                    ),
                }
            )
            return subprocess.run(command, env=env, check=False).returncode
        finally:
            delete_ephemeral_key(key_resource, access_token)


if __name__ == "__main__":
    raise SystemExit(main())
