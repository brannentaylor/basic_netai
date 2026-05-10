# Ansible — CSR lab

Applies **Gi1 + OSPF** and **syslog forwarding** from the Ubuntu control node.

## Install Ansible + collections

Ansible is **not** a system package on a fresh Ubuntu install. This repo installs **`ansible-core`** via **uv** (same toolchain as Python).

From the **repository root**:

```bash
cd ~/basic_netai
uv sync --all-groups
```

Install required collections (**no sudo** — they go under `~/.ansible/collections`). From the repo root, **`uv sync --all-groups`** pulls **`ansible-pylibssh`** so **network_cli** prefers **libssh** over paramiko (fewer **host key mismatch** surprises when CSR keys rotate).

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
- `inventory/group_vars/csr_lab.yml` — connection + **`lab_syslog_collector_ipv4`** (VM on `10.0.0.0/24`). Set **`csr_logging_source_interface`** only when you know which interface reliably reaches that subnet.
- `inventory/host_vars/` — per-router **router-id** and **Gi1 IPv4** within `192.168.254.0/29`.

Vars live **under `inventory/`** alongside `hosts.yml` so Ansible merges them (`ansible_connection: ansible.netcommon.network_cli` applies to **`cisco.ios`** modules — plain `ssh` fails with “not valid for this module”).

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

1. **rsyslog on the VM** (localhost, requires root once — see **Ubuntu + sudo-rs** above). **Default on sudo-rs hosts:** use interactive `sudo` once (Option A), not the playbook.

   From **repository root**:

   ```bash
   sudo bash infra/syslog/install_receiver.sh
   ```

   You will be prompted for **your Linux account password** (`brannen`), not CSR `cisco`. After it finishes, confirm **UDP/514** listening: `ss -ulnp | grep ':514'` and check `/var/log/network-lab/` exists.

   Whenever **`infra/syslog/rsyslog.d/basic_netai-remote.conf`** changes (**`git pull`**), rerun that installer (or Ansible **`syslog_server.yml`**) plus **`sudo systemctl restart rsyslog`** so **`/var/log/network-lab/all.log`** stays tied to **`imudp/514`** only — see **`docs/monitoring/syslog.md`**.

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

SNMP read-only toward **TIGger** (**Phase A2** — **`docs/monitoring/tig/snmp-ios-xe.md`**). The playbook binds **`snmp-server community … RO`** to a **numbered standard ACL** (default **87**, **`csr_snmp_standard_acl_num`** in **`group_vars/csr_lab.yml`**). TIGger source IP: **`tigger_snmp_collector_ipv4`**.

```bash
export CSR_SNMP_RO_COMMUNITY='your-lab-read-only-string'
uv run ansible-playbook playbooks/csr_snmp.yml --diff
uv run ansible-playbook playbooks/verify_csr_snmp.yml
```

On **TIGger**, after apply: **`sudo apt-get install -y snmp`**, then for example **`snmpget -v2c -c "$SNMP_RO_COMMUNITY" 10.0.0.22 1.3.6.1.2.1.1.5.0`** (replace with each CSR **`ansible_host`** from **`hosts.yml`**). Do not type angle-bracket placeholders into **`bash`** — **`<foo>`** is input redirection.

3. **Loopback0 + controlled OSPF redistribution** (human-gated — read the design first):

   Peer review: **`docs/design/2026-05-09-loopback-ospf-redistribution.md`**

   ```bash
   # Dry-run — no device changes; inspect output and diffs
   uv run ansible-playbook playbooks/loopback_redistribute.yml --check --diff

   # After sign-off — applies config and saves when changed
   uv run ansible-playbook playbooks/loopback_redistribute.yml --diff

   # Read-only verification (show outputs)
   uv run ansible-playbook playbooks/verify_loopback_ospf.yml
   ```

4. **EXEC aliases** (human-gated — read the design first):

   Peer review: **`docs/design/2026-05-09-ios-exec-aliases.md`**

   ```bash
   uv run ansible-playbook playbooks/exec_aliases.yml --check --diff
   uv run ansible-playbook playbooks/exec_aliases.yml --diff
   uv run ansible-playbook playbooks/verify_exec_aliases.yml
   ```

Use `--check` / diff mode when experimenting.

## Baseline snapshots (read-only, for outage diff / rollback forensics)

`playbooks/snapshot_configs.yml` captures **startup + running configuration**, IPv4 (**and IPv6 if present**) **routing summaries**, detailed **OSPF neighbour + database-summary** telemetry, optionally **CDP** (often fails on routers with CDP disabled), and emits a **hybrid** artefact bundle under **`artifacts/baselines/<UTC_timestamp>/`** on **this workstation**:

- **numbered `*.txt` per CSR** — human **`diff`** workflow (tiny headers + verbatim IOS text)
- **`telemetry.json` per CSR** — the same IOS captures structured for **`jq`**, scripts, agents (**`capture_format_version`**, **`captures[].{artifact,command,ok,msg,stdout,stdout_lines}`**)
- **`manifest.json`** at the snapshot root — expected **`*.txt`** filenames (`vars/baseline_snapshot_commands.yml`) plus host roster

Details and **`jq` examples**: [`artifacts/baselines/README.md`](artifacts/baselines/README.md).

**Secrets warning:** **`30_running-config.txt`** can include credentials or keys — **`artifacts/baselines/*`** is **`gitignored`** except **`baselines/README.md`**.

Because data must be read live from routers, Ansible **`--check` does _not_ collect meaningful output** — run this playbook normally (no **`--check`**) when you genuinely want baseline files written.

Do **not** use **`ansible-playbook --limit …`** unless you widen the selector to whatever your Ansible inventory names the controller (`localhost`): the playbook needs the opening **`hosts: localhost`** play to mint the shared **`network_baseline_id`**.

From **`infra/ansible/`**:

```bash
uv run ansible-playbook playbooks/snapshot_configs.yml
```

After stable changes (for example routing policy or loopback rollout), rerun and store snapshots alongside your archive policy (offline tarball, Vault, CMDB attachments).

## Firewall reminder

Allow **UDP/514** from `10.0.0.0/24` to this host only, for example:

```bash
sudo ufw allow from 10.0.0.0/24 to any port 514 proto udp
```

Documented in `docs/monitoring/syslog.md`.
