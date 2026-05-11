# ADR 0002 — OSPF area 0 + UDP syslog

**Topology update (post-merge):** OSPF underlay is no longer a single **Gi1** broadcast **`/29`**; the lab uses a **Gi2/Gi3 triangle** of **`/30`** links (**`iosxe_triangle_ospf.j2`**). The decision below still applies in spirit (internal transit vs redistributed loopback).

## Status

Accepted (lab scope)

## Context

We need a routed **OSPF** control plane between lab CSRs and centralized logs for troubleshooting/agent reasoning.

## Decision

- Run **OSPFv2 area 0** on the lab triangle + cloud links (current Ansible: **`10.0.12/13/23.0/24`** + **`10.0.0.0/24`** on **Gi4** passive; older Gi1 **`/29`** / **`192.168.254.*`** retired).
- Use **rsyslog** on Ubuntu with **UDP/514**; CSR `logging host` targets the VM management address.
- Document firewall scope (**10.0.0.0/24**) and cleartext risks.

## Consequences

- Easy packet capture + classic `show ip ospf` troubleshooting.
- Must harden or move to **TCP/TLS syslog** before any sensitive environment.
