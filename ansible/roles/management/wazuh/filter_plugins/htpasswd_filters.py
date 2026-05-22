"""Custom Ansible filter leveraging `htpasswd` for bcrypt hashing.

This avoids the control-node dependency on passlib's bcrypt backend,
which currently breaks under Python 3.13. It shells out to the
system `htpasswd` utility to produce `$2y$` bcrypt hashes.
"""

from __future__ import annotations

import shutil
import subprocess
from typing import Any


class FilterModule:
    """Expose custom filters to Ansible."""

    def filters(self) -> dict[str, Any]:
        return {
            "htpasswd_bcrypt": htpasswd_bcrypt,
        }


def htpasswd_bcrypt(password: str, cost: int = 12) -> str:
    """Return a bcrypt hash for ``password`` using the `htpasswd` CLI.

    Args:
        password: Plain-text password to hash.
        cost: Bcrypt cost factor (number of rounds). Defaults to 12.

    Raises:
        AnsibleFilterError: If the helper command is missing or fails.
    """

    from ansible.errors import AnsibleFilterError

    if password is None:
        raise AnsibleFilterError("htpasswd_bcrypt filter received a null password")

    htpasswd_path = shutil.which("htpasswd")
    if not htpasswd_path:
        raise AnsibleFilterError("`htpasswd` executable not found on control node")

    if not isinstance(cost, int) or cost < 4 or cost > 31:
        raise AnsibleFilterError("htpasswd_bcrypt cost must be an integer between 4 and 31")

    cmd = [htpasswd_path, "-nB", "-C", str(cost), "-i", "ansible"]

    try:
        result = subprocess.run(
            cmd,
            input=f"{password}\n".encode("utf-8"),
            check=True,
            capture_output=True,
        )
    except subprocess.CalledProcessError as exc:
        stderr = exc.stderr.decode("utf-8", errors="ignore").strip()
        raise AnsibleFilterError(f"htpasswd command failed: {stderr or exc}") from exc

    output = result.stdout.decode("utf-8", errors="ignore").strip()
    try:
        _, hashed = output.split(":", 1)
    except ValueError as exc:
        raise AnsibleFilterError(f"Unexpected htpasswd output: {output}") from exc

    normalized = hashed.strip()
    if normalized.startswith("$2y$"):
        normalized = "$2b$" + normalized[4:]

    return normalized
