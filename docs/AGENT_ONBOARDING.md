# Agent onboarding — `basic_netai` project context

**Read this document first** when you are a new coding agent (or human collaborator) picking up this repository. It summarizes **what the project is**, **where things live**, **conventions that bite if wrong**, and **what was built during the main development thread** (condensed facts, not a chat transcript).

Safety and tool guardrails: **`docs/agent-ops/safety.md`** (read-only bias, truncation, no arbitrary CLI as default).

---

## 1. What this project is

- **Purpose:** Small **lab** for **AI-assisted network operations** against **Cisco CSR1000v** routers.
- **Runtime:** One **Ubuntu control host** on **`10.0.0.0/24`** and **three CSRs** (**`csr_lab`** in Ansible inventory). Default management IPv4 examples: **`10.0.0.20` / `10.0.0.23` / `10.0.0.22`** (see **[`infra/ansible/inventory/hosts.yml`](../infra/ansible/inventory/hosts.yml)** — **IPs can change**).
- **Transit lab:** Gi1 multi-access **`192.168.254.0/29`** with **OSPF area 0** (playbook-driven).
- **Centralized syslog:** CSR **`logging host`** → Ubuntu **`10.0.0.21:514/UDP`** (**`lab_syslog_collector_ipv4`** in group vars). Aggregated file **`/var/log/network-lab/all.log`** (**gitignored** payloads under **`artifacts/`**, not full OS logs when rsyslog fragment is current).

This is **not production** equipment policy; treat passwords and configs as **lab-only**.

---

## 2. Repo map (where to look)

| Path | Role |
| --- | --- |
| **`src/network_lab/`** | Python package: inventory helpers, **scrapli** + **system SSH**, tests, optional **`read_recent_lab_syslog_lines()`** (bounded). |
| **`infra/ansible/`** | **Ansible**: inventory ([`inventory/hosts.yml`](../infra/ansible/inventory/hosts.yml)), **`group_vars`/`host_vars`**, **playbooks**, **Jinja IOS templates**, local **baseline artefacts** directory. |
| **`infra/syslog/`** | **`rsyslog`** drop-in (**UDP-only ruleset** routing `imudp` → **`network-lab/all.log`**), **`install_receiver.sh`**. |
| **`docs/`** | Topology, replication, ADRs, monitoring, **agent ops**, **instruction manual** (CLI engineers), **design** peer-review notes, **journal** entries. |
| **Root `README.md`** | Human quick start; points here via **`AGENTS.md`**. |

Broader layout: **`docs/architecture.md`**.

---

## 3. Conventions agents must respect

| Topic | Detail |
| --- | --- |
| **Python toolchain** | **`uv sync --all-groups`**; run tests with **`uv run pytest`**. Package import name: **`network_lab`**. |
| **Ansible cwd** | Always **`cd infra/ansible`** before **`uv run ansible-playbook`** so **`ansible.cfg`** and **`inventory/hosts.yml`** resolve (**`inventory` lives under `infra/ansible/inventory/`**). |
| **Connection to CSRs** | **`ansible_connection: ansible.netcommon.network_cli`** (**not** plain `ssh`). IOS modules: **`cisco.ios.*`**. |
| **Credentials** | **`CSR_SSH_USERNAME`**, **`CSR_SSH_PASSWORD`** (env). Never commit secrets. |
| **Human-gated change** | **`loopback_redistribute.yml`**, **`exec_aliases.yml`** pair with **`docs/design/`**; prefer **`--check --diff`** before apply workflows described in **`infra/ansible/README.md`**. |
| **Baseline snapshots** | **`playbooks/snapshot_configs.yml`** writes **`artifacts/baselines/<UTC>/`**. **No `--check`** for real capture; avoid **`--limit`** without including **`localhost`** play (timestamp id). Outputs may contain **secrets** (**`running-config`**). |
| **Syslog receiver upgrades** | After **`git pull`** touching **`infra/syslog/rsyslog.d/`**, reinstall fragment + **`systemctl restart rsyslog`** on the collector (**`docs/monitoring/syslog.md`**). |

CLI-first human guide (non-agent-specific): **`docs/instruction_manual_ansible_lab.md`**.

---

## 4. Discussion context — what was implemented (summary)

These items reflect the **intent of the project thread**; exact Git history is **`git log`.

| Area | Notes |
| --- | --- |
| **Routing baseline** | **`site_routing.yml`** + **`templates/iosxe_gi1_ospf.j2`**: Gi1 addressing, **OSPF 1**, **`router-id`** per **`host_vars`**, passive default except Gi1. |
| **Syslog from CSRs** | **`csr_logging.yml`** + **`templates/iosxe_logging.j2`** toward **`lab_syslog_collector_ipv4`**. |
| **Loopback + OSPF redistribution** | Design **`docs/design/2026-05-09-loopback-ospf-redistribution.md`**; playbook **`loopback_redistribute.yml`** (**prefix-list**, **route-map**, **`redistribute connected … metric-type 1`**); verify **`verify_loopback_ospf.yml`**. |
| **EXEC aliases** | Design **`docs/design/2026-05-09-ios-exec-aliases.md`**; **`exec_aliases.yml`** + **`verify_exec_aliases.yml`**. |
| **Baseline forensics** | **`snapshot_configs.yml`**: per-CSR numbered **`*.txt`** (human **`diff`**) **and** **`telemetry.json`** (structured **`captures[]`**) **and** snapshot-root **`manifest.json`**. Command list: **`playbooks/vars/baseline_snapshot_commands.yml`**. |
| **Playbook fixes** | **`snapshot_configs`**: avoid **`item`** in task **names**; loop register uses **`snapshot_line`** not **`item`**; **`stdout_lines` flattened** for file bodies. |
| **Rsyslog correctness** | Global **`*.*` → `all.log`** duplicated **local Ubuntu** logs; fixed with **dedicated `ruleset`** bound to **`imudp`**. |
| **Docs** | Instruction manual, journal wrap **`docs/journal/2026-05-09-ansible-syslog-session.md`**, runbook / monitoring updates. |

Strategic note (from discussion, not code): **Ansible** is the primary **declarative** vehicle here; **NETCONF/RESTCONF** can be a future layer for **more structured** agent reads.

**TIG telemetry:** Telegraf + InfluxDB + Grafana on **TIGger** (**not** the syslog/control VM on **`10.0.0.0/24`** — **`docs/monitoring/tig/README.md`**). **Lab TIGger mgmt IP:** **`10.0.0.24`**. **Phase A2 SNMP** uses **`infra/ansible/playbooks/csr_snmp.yml`**: **numbered standard ACL** (default **`87`**, **`csr_snmp_standard_acl_num`** in **`group_vars/csr_lab.yml`**), **`snmp-server community … RO 87`** — avoids CSR1000v failures seen with **named extended** ACL binds. **Operational check:** **`snmpget`** **sysName** from TIGger → each **`ansible_host`**; then **`infra/tig/install_telegraf_snmp_csr.sh`** (details **`snmp-ios-xe.md`**). **Phase A3:** import **`infra/tig/grafana/dashboards/csr-snmp-overview.json`** (**`infra/tig/grafana/README.md`**). **gNMI deferred** (**`docs/monitoring/tig/gnmi-roadmap.md`**) until IOS upgrade — **`docs/design/2026-05-10-tigger-TIG-snmp-phased.md`**.

---

## 5. Suggested read order (10–15 minutes)

1. Root **`README.md`** (skim).
2. This file (**`docs/AGENT_ONBOARDING.md`**).
3. **`docs/agent-ops/safety.md`**
4. **`infra/ansible/README.md`**
5. **`docs/topology.md`** or **`docs/HOW_TO_REPLICATE.md`** as needed.
6. **`docs/monitoring/syslog.md`** if touching logging.
7. **`CONTRIBUTING.md`** before submitting changes.

---

## 6. Quick command reminders

```bash
# Python
cd ~/basic_netai && uv sync --all-groups && uv run pytest

# Ansible (from infra/ansible)
export CSR_SSH_USERNAME=cisco
export CSR_SSH_PASSWORD='…'
uv run ansible-playbook playbooks/site_routing.yml --diff

# Baseline snapshot (writes under infra/ansible/artifacts/baselines/)
uv run ansible-playbook playbooks/snapshot_configs.yml
```

---

## 7. Out of scope / do not assume

- No guarantee ADRs exist for every knob; check **`docs/decisions/`**.
- **Inventory IPs and hostnames** are **lab examples** — verify **`hosts.yml`** before automation.
- **`email.md`** or other personal scratch files may appear; do not commit correspondence unless the owner asks.

---

_This file is the durable substitute for “what we discussed in chat.” Update it when major behaviour or layout changes._
