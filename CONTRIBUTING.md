# Contributing and operations

Thanks for improving `basic_netai`. This repo is optimized for:

- repeatable **infra-as-code** (Ansible),
- readable **Python** (`network_lab` package),
- escalation to **human network engineers**.

## Prerequisites

- **Python 3.13** plus [uv](https://github.com/astral-sh/uv).
- CSR lab reachable by SSH (`10.0.0.0/24` in the default example).
- **Ansible + collections** (`cisco.ios`) for router playbooks — see [`infra/ansible/README.md`](infra/ansible/README.md).

## Everyday checks

```bash
uv sync --all-groups
uv run ruff check src tests
uv run ruff format src tests
uv run pytest
```

Target CI (not wired yet): the same checks plus optional `ansible-lint`.

## Handling secrets

- Never commit **`CSR_SSH_PASSWORD`**, SNMP strings, Vault keys, or private keys.
- Prefer environment variables sourced from files **outside** Git. See [`docs/REDACTION.md`](docs/REDACTION.md).
- Prefer **ansible-vault** for Ansible-managed secrets once playbooks stabilize.

## Asking someone for network help

Include:

1. Topology slice — see [`docs/topology.md`](docs/topology.md) and [`docs/ip-plan.md`](docs/ip-plan.md).
2. The exact **playbook name** (`infra/ansible/playbooks/...`).
3. `show tech` excerpts only if attachments are sanitized (internal policies apply).
4. Management reachability ping + `ansible ... -m ansible.builtin.ping` where relevant.

Agents should summarize device output for humans rather than dumping unbounded blobs.

## Change style

Small commits (`docs:`, `ansible:`, `fix:`). Update matching **journal / ADRs** when the change teaches something others should replay.
