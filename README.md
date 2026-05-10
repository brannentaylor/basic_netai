# basic_netai

Experimental lab for **AI-assisted network operations** with simple, reviewable automation.

Lab tooling and infrastructure-as-code for building **network-aware AI agents** against **Cisco CSR 1000v** routers. Runs on an Ubuntu control host on `10.0.0.0/24` beside three lab CSRs.

**Repository:** [`git@github.com:brannentaylor/basic_netai.git`](git@github.com:brannentaylor/basic_netai.git)  
**HTTPS:** [`https://github.com/brannentaylor/basic_netai.git`](https://github.com/brannentaylor/basic_netai.git)

Python import package: **`network_lab`** (project name on PyPI style: `basic-netai`).

## Follow along

Public build log, ADRs, replication steps, and agent-safety notes live under [`docs/README.md`](docs/README.md).

**New AI agent or collaborator:** read [`AGENTS.md`](AGENTS.md) → [`docs/AGENT_ONBOARDING.md`](docs/AGENT_ONBOARDING.md) first.

## For human network engineers

- [`CONTRIBUTING.md`](CONTRIBUTING.md) — how to change the repo safely, run checks, escalate.
- [`infra/ansible/`](infra/ansible/) — intended router state (routing, logging).
- [`docs/instruction_manual_ansible_lab.md`](docs/instruction_manual_ansible_lab.md) — how Ansible fits this repo (for CLI-first engineers).
- [`docs/ip-plan.md`](docs/ip-plan.md) — numbering source of truth once filled in.
- [`docs/monitoring/syslog.md`](docs/monitoring/syslog.md) — syslog receiver on this VM.
- [`docs/journal/2026-05-09-ansible-syslog-session.md`](docs/journal/2026-05-09-ansible-syslog-session.md) — example dated wrap (baseline JSON, syslog ruleset recap).

## Quick start (Python)

Install [uv](https://github.com/astral-sh/uv) (binary at `~/.local/bin/uv`; if **`uv: command not found`**, run `source ~/.local/bin/env` or open a new login shell).

Then:

```bash
git clone git@github.com:brannentaylor/basic_netai.git
cd basic_netai
uv sync --all-groups
```

Copy [`.env.example`](.env.example) into your shell environment (or a local `.env` you `source` manually—**do not** commit secrets).

```bash
export LAB_INVENTORY_PATH=src/network_lab/inventory/inventory.example.yaml
export CSR_SSH_USERNAME=cisco
export CSR_SSH_PASSWORD='your-lab-password'

uv run pytest
```

`network_lab` connects with **scrapli** using the **system** OpenSSH client so your user-level [`~/.ssh/config`](https://man.openbsd.org/ssh_config.5) applies (for example legacy CSR KEX negotiation).

After rsyslog is running, agents may call `network_lab.tools.read_recent_lab_syslog_lines()` (bounded tail under `/var/log/network-lab/`) — see `docs/agent-ops/safety.md`.

## Ansible (Phase 2)

See [`infra/ansible/README.md`](infra/ansible/README.md).

## License

MIT — see [`LICENSE`](LICENSE).
