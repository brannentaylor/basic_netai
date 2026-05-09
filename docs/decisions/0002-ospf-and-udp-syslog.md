# ADR 0002 — OSPF area 0 on Gi1 + UDP syslog

## Status

Accepted (lab scope)

## Context

We need a routed control plane on a shared L2 Gi1 segment and centralized logs for troubleshooting/agent reasoning.

## Decision

- Run **OSPFv2 area 0** on **`192.168.254.0/29`** across Gi1.
- Use **rsyslog** on Ubuntu with **UDP/514**; CSR `logging host` targets the VM management address.
- Document firewall scope (**10.0.0.0/24**) and cleartext risks.

## Consequences

- Easy packet capture + classic `show ip ospf` troubleshooting.
- Must harden or move to **TCP/TLS syslog** before any sensitive environment.
