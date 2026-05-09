# Repository architecture

Everything for this learning lab intentionally lives in **one** Git repo (`basic_netai`):

| Area | Role |
| --- | --- |
| `src/network_lab` | Typed inventory + SSH tooling for agents/tests |
| `infra/ansible` | Declarative CSR + localhost (rsyslog) configuration |
| `infra/syslog` | Raw rsyslog fragments versioned beside Ansible |
| `docs/` | External narrative (topology, replication, ADRs, agent policy) |

## When to split

Consider a second repo only if:

- Ansible/Terraform grows beyond a few hundred lines and needs its own release cadence, or
- A reusable `network_lab` library should publish to an internal package index.

Document the split with a superseding ADR in `docs/decisions/`.
