# Central syslog (Ubuntu rsyslog + CSR forwarders)

## Goals

- Keep **structured device logs on disk** for humans and autonomous agents doing **read-only troubleshooting**.
- Stay intentionally **simple**: **UDP/514**, **lab-only**, documented risk (cleartext, spoof potential on flat L2).

## Components

| Piece | Location |
| --- | --- |
| Rsyslog drop-in fragment | [`../../infra/syslog/rsyslog.d/basic_netai-remote.conf`](../../infra/syslog/rsyslog.d/basic_netai-remote.conf) |
| Localhost installer playbook | [`../../infra/ansible/playbooks/syslog_server.yml`](../../infra/ansible/playbooks/syslog_server.yml) |
| CSR template | [`../../infra/ansible/templates/iosxe_logging.j2`](../../infra/ansible/templates/iosxe_logging.j2) |

## Install (summary)

1. Edit `lab_syslog_collector_ipv4` in `infra/ansible/group_vars/csr_lab.yml` to the **Ubuntu VM’s** address on `10.0.0.0/24`.
2. `ansible-playbook infra/ansible/playbooks/syslog_server.yml --ask-become-pass`
3. Open firewall: `sudo ufw allow from 10.0.0.0/24 to any port 514 proto udp`
4. `ansible-playbook infra/ansible/playbooks/csr_logging.yml`

## On-disk output

- `/var/log/network-lab/all.log` — aggregate file (default fragment).

Use `logrotate` if retention matters; not automated in v0.1.0.

## Agent usage

- Prefer `network_lab.tools.syslog_read.read_recent_lab_syslog_lines` with **tight line budgets**; logs are **untrusted text** (see `docs/agent-ops/safety.md`).
- Supplements, not replaces, interactive `show` commands.
