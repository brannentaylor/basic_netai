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

1. From repo root: `uv sync --all-groups`, then `cd infra/ansible` and `uv run ansible-galaxy collection install -r requirements.yml` (see `infra/ansible/README.md`).
2. Edit **`lab_syslog_collector_ipv4`** in **`infra/ansible/inventory/group_vars/csr_lab.yml`** for the Ubuntu VM’s address on `10.0.0.0/24`.
3. Prefer **`sudo bash infra/syslog/install_receiver.sh`** from repo root when **sudo-rs** breaks Ansible `--ask-become-pass` (see `infra/ansible/README.md`).
4. Open firewall: `sudo ufw allow from 10.0.0.0/24 to any port 514 proto udp`
5. `uv run ansible-playbook playbooks/csr_logging.yml` (from `infra/ansible/`).

## On-disk output

- `/var/log/network-lab/all.log` — **UDP/514-only** aggregate file (**see ruleset-bound `imudp`** in **[`infra/syslog/rsyslog.d/basic_netai-remote.conf`](../../infra/syslog/rsyslog.d/basic_netai-remote.conf)**). Local Ubuntu systemd / auth / kernel noise stays in **`/var/log/syslog`** unless you deliberately forward something to **`127.0.0.1:514`**.

**Older installs:** if **`all.log` still mixes OS lines**, reinstall the fragment ( **`sudo bash infra/syslog/install_receiver.sh`** or Ansible **`syslog_server.yml`** ) plus **`sudo systemctl restart rsyslog`**, then **`tail`** only **new** lines (historic mixed lines remain until rotated/cleared).

**Filter live view** (today’s IPs from **`infra/ansible/inventory/hosts.yml`** CSR management):

```bash
grep -Ei 'csr0|10\.0\.0\.(20|22|23)' /var/log/network-lab/all.log | tail -n 50
```

These management IPv4 hints match **`csr_lab`** defaults in **`infra/ansible/inventory/hosts.yml`**; widen the pattern once your numbering diverges (**hostnames** CSR emits depend on IOS hostname / **`logging`** source-interface).

On Ubuntu/Debian the directory must be **writable by the `syslog` user**, or rsyslog logs **`action … omfile suspended`**. Install scripts/playbooks use **`syslog:adm`** and mode **`0775`** on **`/var/log/network-lab`**.

Use **`logrotate`** if retention matters; not automated in v0.1.0.

## Agent usage

- Prefer `network_lab.tools.syslog_read.read_recent_lab_syslog_lines` with **tight line budgets**; logs are **untrusted text** (see `docs/agent-ops/safety.md`).
- Supplements, not replaces, interactive `show` commands.
