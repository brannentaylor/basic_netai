"""Typed records parsed from inventory YAML."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class DeviceRecord:
    """Single lab router entry — management IP is the SSH target."""

    hostname: str
    management_ipv4: str
    platform: str
    environment: str = "lab"
