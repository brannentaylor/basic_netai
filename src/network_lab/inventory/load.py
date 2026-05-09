"""Parse inventory YAML into ``DeviceRecord`` tuples."""

from __future__ import annotations

from collections.abc import Sequence
from pathlib import Path

import yaml

from network_lab.inventory.models import DeviceRecord


class InventoryError(RuntimeError):
    """Raised when inventory YAML structure is invalid."""

    pass


def load_devices(path: Path) -> tuple[DeviceRecord, ...]:
    """Load YAML containing a top-level ``devices`` list."""

    if not path.is_file():
        raise InventoryError(f"Inventory file missing: {path}")

    payload = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    rows = payload.get("devices")

    if not isinstance(rows, list):
        raise InventoryError("`devices` key must contain a YAML list.")

    devices: list[DeviceRecord] = []
    for index, raw in enumerate(rows):
        device = _row_to_record(raw, row_index=index)
        devices.append(device)

    return tuple(devices)


def device_by_hostname(devices: Sequence[DeviceRecord], hostname: str) -> DeviceRecord:
    """Resolve a hostname (case-sensitive) against a cached inventory."""

    for device in devices:
        if device.hostname == hostname:
            return device

    choices = ", ".join(sorted(entry.hostname for entry in devices))
    raise LookupError(f"Unknown hostname `{hostname}`; known hosts: {choices}")


def _row_to_record(raw: object, *, row_index: int) -> DeviceRecord:
    if not isinstance(raw, dict):
        raise InventoryError(f"devices[{row_index}] must map keys to values.")

    try:
        hostname = str(raw["hostname"]).strip()
        management_ipv4 = str(raw["management_ipv4"]).strip()
        platform = str(raw["platform"]).strip()
    except KeyError as exc:
        raise InventoryError(f"devices[{row_index}] missing `{exc.args[0]}` field.") from exc

    if not hostname or not management_ipv4 or not platform:
        raise InventoryError(f"devices[{row_index}] has blank required string fields.")

    environment = raw.get("environment", "lab")
    if environment is None:
        environment = "lab"
    environment_str = str(environment).strip() or "lab"

    return DeviceRecord(
        hostname=hostname,
        management_ipv4=management_ipv4,
        platform=platform,
        environment=environment_str,
    )
