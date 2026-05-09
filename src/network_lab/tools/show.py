"""Read-only CLI helpers — prefer these before any configuration tool exists."""

from __future__ import annotations

from collections.abc import Mapping
from pathlib import Path

from network_lab import config
from network_lab.connection.driver import open_iosxe_session
from network_lab.inventory.load import device_by_hostname, load_devices


def run_show_command(
    hostname: str,
    command: str,
    *,
    inventory_path: Path | None = None,
    env: Mapping[str, str] | None = None,
) -> str:
    """Execute a single ``show ...`` style command and return combined output.

    Args:
        hostname: Matches ``hostname`` field in inventory YAML.
        command: Full IOS-XE command string (callers should avoid free-form ``conf t``).
        inventory_path: Override path; defaults to ``config.inventory_path(env)``.
        env: Optional environment mapping for tests / non-default credentials.

    Returns:
        Device response text (may be large — truncate before sending to an LLM).

    Raises:
        LookupError: Unknown hostname.
        FileNotFoundError: Missing inventory file.
    """

    path = inventory_path or config.inventory_path(env)
    devices = load_devices(path)
    device = device_by_hostname(devices, hostname)

    username = config.ssh_username(env)
    password = config.ssh_password(env)

    with open_iosxe_session(device, username=username, password=password) as conn:
        result = conn.send_command(command)
        return result.result
