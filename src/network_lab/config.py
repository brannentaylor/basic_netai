"""Load environment-driven settings for CLI and agent tooling.

Lab credentials SHOULD come from the environment — avoid routing secrets via LLMs;
see docs/agent-ops/safety.md.
"""

from __future__ import annotations

import os
from collections.abc import Mapping
from pathlib import Path

_ENV_INVENTORY_PATH = "LAB_INVENTORY_PATH"
_ENV_SSH_USERNAME = "CSR_SSH_USERNAME"
_ENV_SSH_PASSWORD = "CSR_SSH_PASSWORD"


def default_inventory_path(cwd: Path | None = None) -> Path:
    """Fallback inventory path used when LAB_INVENTORY_PATH is unset."""

    root = cwd or Path.cwd()
    return root / "src" / "network_lab" / "inventory" / "inventory.example.yaml"


def inventory_path(env: Mapping[str, str] | None = None) -> Path:
    """Resolved path to device inventory YAML.

    Args:
        env: Mapping (defaults to ``os.environ``). Primarily for testing.

    Returns:
        Absolute ``Path`` for the YAML file (existence not checked here).
    """

    source = dict(os.environ) if env is None else dict(env)
    raw = source.get(_ENV_INVENTORY_PATH)
    if raw:
        path = Path(raw).expanduser()
        if not path.is_absolute():
            path = Path.cwd() / path
        return path.resolve()

    return default_inventory_path().resolve()


def ssh_username(env: Mapping[str, str] | None = None) -> str:
    """SSH user for CSR management access."""

    source = os.environ if env is None else env
    user = source.get(_ENV_SSH_USERNAME, "cisco")
    if not user:
        raise ValueError(f"{_ENV_SSH_USERNAME} must be non-empty when set.")
    return user


def ssh_password(env: Mapping[str, str] | None = None) -> str:
    """SSH password for CSR lab accounts (prefer keys/Vault longer term)."""

    source = os.environ if env is None else env
    return source.get(_ENV_SSH_PASSWORD, "")
