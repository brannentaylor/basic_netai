# Ansible — CSR lab

Applies **Gi1 + OSPF** and **syslog forwarding** from the Ubuntu control node.

## Install Ansible + collections

Ansible is **not** a system package on a fresh Ubuntu install. This repo installs **`ansible-core`** via **uv** (same toolchain as Python).

From the **repository root**:

```bash
cd ~/basic_netai
uv sync --all-groups
```

Install required collections (**no sudo** — they go under `~/.ansible/collections`):

```bash
cd ~/basic_netai/infra/ansible
uv run ansible-galaxy collection install -r requirements.yml
```

All playbook commands below use `uv run` from `infra/ansible` so `ansible.cfg` and `-r requirements.yml` paths stay correct:

```bash
cd ~/basic_netai/infra/ansible
```

**Alternative:** `sudo apt install ansible-core` if you prefer a system-wide `/usr/bin/ansible-playbook`; do **not** use `sudo` for `ansible-galaxy collection install`.

## Configure environment

```bash
export CSR_SSH_USERNAME=cisco
export CSR_SSH_PASSWORD='your-password'
```

Edit:

- `inventory/hosts.yml` — management IPs.
- `group_vars/csr_lab.yml` — **`lab_syslog_collector_ipv4`** must be the VM’s address on `10.0.0.0/24`. Set **`csr_logging_source_interface`** only when you know which interface reliably reaches that subnet (often *not* Gi1 after Gi1 becomes pure OSPF transit).
- `host_vars/` — per-router **router-id** and **Gi1 IPv4** within `192.168.254.0/29`.

## Ubuntu + sudo-rs (short troubleshooting)

Ubuntu may ship **sudo-rs**. A few sharp edges:

| Topic | Detail |
| --- | --- |
| **SSH keys vs sudo** | Key-based **`ssh` login does not authenticate `sudo`.** Elevating still needs your **Unix account password**, **NOPASSWD** sudoers rules, or another admin path — not CSR `cisco`, not SSH keys. |
| **NOPASSWD check** | `sudo -n true` → prints nothing and exits 0 if passwordless sudo is allowed. **`sudo-rs: interactive authentication is required`** means **not** NOPASSWD; set **`passwd`** (Linux user) or configure sudoers. |
| **`--ask-become-pass` flaky** | Ansible often passes the sudo password on a pipe; **sudo-rs** sometimes **timeouts** or refuses non-interactive use. Prefer **one real TTY sudo** at the shell (below) instead of Ansible become for localhost. |
| **`playbooks/syslog_server.yml`** | Use this only when **`uv run ansible-playbook …`** works **without** become prompts (e.g. NOPASSWD). Otherwise use **`infra/syslog/install_receiver.sh`** from repo root so you type **`sudo`** once in an interactive terminal. |

**Lab-only automation:** after you have interactive root once (`sudo bash` …), **`sudo visudo -f /etc/sudoers.d/brannen-lab`** can add **`NOPASSWD:ALL`** for your user — **never** reuse that pattern on shared/production hosts.

## Run order (suggested)

1. **rsyslog on the VM** (localhost, requires root once — see **Ubuntu + sudo-rs** above):

   From **repository root**:

   ```bash
   sudo bash infra/syslog/install_receiver.sh
   ```

   **Alternative** (NOPASSWD sudo only):

   ```bash
   cd ~/basic_netai/infra/ansible
   uv run ansible-playbook playbooks/syslog_server.yml
   ```

2. **Routing**, then **logging** (or reverse if you already have L3 toward the VM):

   ```bash
   uv run ansible-playbook playbooks/site_routing.yml
   uv run ansible-playbook playbooks/csr_logging.yml
   ```

Use `--check` / diff mode when experimenting.

## Firewall reminder

Allow **UDP/514** from `10.0.0.0/24` to this host only, for example:

```bash
sudo ufw allow from 10.0.0.0/24 to any port 514 proto udp
```

Documented in `docs/monitoring/syslog.md`.
