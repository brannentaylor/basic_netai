"""Create short-lived Cisco IOS-XE (CSR) CLI sessions over SSH."""

from __future__ import annotations

from collections.abc import Iterator
from contextlib import contextmanager

from scrapli.driver.core import IOSXEDriver

from network_lab.inventory.models import DeviceRecord


@contextmanager
def open_iosxe_session(
    device: DeviceRecord,
    *,
    username: str,
    password: str,
) -> Iterator[IOSXEDriver]:
    """Open IOS-XE driver with sane lab defaults — close on context exit."""

    # ``system`` SSH uses the local OpenSSH client so ~/.ssh/config (e.g. legacy KEX) applies.
    # Fall back documented in README if paramiko negotiation is needed instead.
    driver = IOSXEDriver(
        host=device.management_ipv4,
        auth_username=username,
        auth_password=password,
        auth_strict_key=False,
        transport="system",
        timeout_ops=45,
        timeout_transport=45,
        timeout_socket=45,
    )
    driver.open()

    try:
        yield driver
    finally:
        driver.close()
