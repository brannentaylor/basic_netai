"""YAML-backed device inventory for the CSR lab."""

from network_lab.inventory.load import InventoryError, device_by_hostname, load_devices
from network_lab.inventory.models import DeviceRecord

__all__: list[str] = ["DeviceRecord", "InventoryError", "device_by_hostname", "load_devices"]
