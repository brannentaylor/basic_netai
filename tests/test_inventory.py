"""Tests for YAML inventory loading."""

from __future__ import annotations

from pathlib import Path

import pytest

from network_lab.inventory import DeviceRecord, InventoryError, device_by_hostname, load_devices

_FIXTURE = Path(__file__).resolve().parent / "fixtures" / "sample_inventory.yaml"


def test_load_devices_parses_three_hosts() -> None:
    devices = load_devices(_FIXTURE)
    assert len(devices) == 3
    assert isinstance(devices[0], DeviceRecord)
    assert devices[0].hostname == "csr-test-01"


def test_device_by_hostname_success() -> None:
    devices = load_devices(_FIXTURE)
    resolved = device_by_hostname(devices, "csr-test-02")
    assert resolved.management_ipv4 == "10.0.0.31"


def test_device_by_hostname_missing() -> None:
    devices = load_devices(_FIXTURE)
    with pytest.raises(LookupError):
        device_by_hostname(devices, "unknown")


def test_invalid_devices_key() -> None:
    path = Path(__file__).parent / "fixtures" / "broken_missing_devices.yaml"
    with pytest.raises(InventoryError):
        load_devices(path)


def test_inventory_file_missing() -> None:
    missing = Path(__file__).parent / "fixtures" / "does_not_exist.yaml"
    with pytest.raises(InventoryError, match="missing"):
        load_devices(missing)
