#!/usr/bin/env python3
"""Emit Telegraf [[inputs.snmp]] fragment from Ansible inventory csr_lab hosts only."""

from __future__ import annotations

import argparse
import os
from pathlib import Path

import yaml


def csr_mgmt_ips(inventory_path: Path) -> list[str]:
    data = yaml.safe_load(inventory_path.read_text(encoding="utf-8"))
    try:
        hosts = data["all"]["children"]["csr_lab"]["hosts"]
    except (KeyError, TypeError) as e:
        raise SystemExit(f"Unexpected inventory shape in {inventory_path}: {e}") from e
    if not hosts or not isinstance(hosts, dict):
        raise SystemExit(f"No csr_lab.hosts mapping in {inventory_path}")

    ips: list[str] = []
    for hostname in sorted(hosts.keys()):
        meta = hosts[hostname]
        if not isinstance(meta, dict):
            continue
        ip = meta.get("ansible_host")
        if not ip:
            raise SystemExit(f"Missing ansible_host for {hostname!r} in {inventory_path}")
        ips.append(str(ip))

    if not ips:
        raise SystemExit(f"No usable csr_lab ansible_host entries in {inventory_path}")
    return ips


def render(agents: list[str], interval: str) -> str:
    agents_toml = ", ".join(f'"{a}"' for a in agents)
    return f"""\
# Repo: basic_netai — Phase A2 CSR SNMP (generated).
# Re-run infra/tig/install_telegraf_snmp_csr.sh after inventory edits.
[[inputs.snmp]]
  name = "csr_snmp"
  agents = [{agents_toml}]
  version = 2
  community = "${{SNMP_RO_COMMUNITY}}"
  interval = "{interval}"
  timeout = "5s"
  retries = 3

  [[inputs.snmp.field]]
    name = "sysName"
    oid = "1.3.6.1.2.1.1.5.0"
    is_tag = true

  [[inputs.snmp.field]]
    name = "sysUpTime"
    oid = "1.3.6.1.2.1.1.3.0"
"""


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--inventory", type=Path, required=True)
    p.add_argument("--interval", default="60s")
    p.add_argument("--out", type=Path, required=True)
    args = p.parse_args()

    agents = csr_mgmt_ips(args.inventory)
    text = render(agents, args.interval)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    tmp = args.out.with_name(f".{args.out.name}.{os.getpid()}.tmp")
    tmp.write_text(text, encoding="utf-8")
    os.rename(tmp, args.out)


if __name__ == "__main__":
    main()
