# Instruction manual — Ansible for `basic_netai` (network-engineer mindset)

This document is aimed at engineers who routinely drive changes from the **CLI on the router** (**`configure terminal`**, **`copy run start`**, **`show`** / **`terminal length 0`**) and now need to collaborate with—or operate—the **Ansible automation** bundled in **`basic_netai`**.

Ansible **does not replace** IOS knowledge. It repeats your intent across devices with **fewer keystrokes**, **fewer mismatches**, and **reviewable artefacts** (**`--diff`**, Git, **`telemetry.json`**). You remain responsible for validating outcomes on the **`show`** output you trust.

---

## 1. How this repo thinks about automation

The repository separates two roles:

| Area | What it is |
| --- | --- |
| **`src/network_lab/`** | Python tooling (scrapli/OpenSSH integration, tests, inventories for **agents**). |
| **`infra/ansible/`** | **Ansible** — versioned snippets of IOS-XE you want routers and the Ubuntu VM to hold. |

The high-level sketch is duplicated in **[`docs/architecture.md`](architecture.md)**.

For **changing CSR configuration**, **`infra/ansible/`** is the directory you operate from.

---

## 2. Ansible in one paragraph (CLI analogy)

Imagine you keep a **`notepad`** of every command you typed on **three** routers, grouped by scenario (“Gi1 addressing + OSPF”, “logging to VM”, …). Ansible’s **playbook** is that notepad executable: for each **`host:`** router, Ansible **opens SSH** (**via the Ansible network stack**, not vanilla `ansible_ssh` toward IOS), executes **modules**, and optionally **shows you the diff**.

| Manual habit | Rough Ansible analogue |
| --- | --- |
| Paste a stanza after **`conf t`** | **`cisco.ios.ios_config`** **`lines`** + **`parents`**, or a **Jinja2 template** pushed as **`ios_config`** **`src`** |
| **`show run`** to verify before save | **`--check`** (simulation, where supported), **`verify_*.yml`** read-only playbooks, or **`snapshot_configs.yml`** artefacts |
| Same change on csr01→03 | **`hosts: csr_lab`** in one playbook |

Ansible prefers **intent** (**“these lines belong under `router ospf 1`”**) rather than keystroke-perfect screen scraping. That aligns with IOS **merge** semantics for well-scoped snippets.

---

## 3. Workstation prerequisites (your Linux laptop or lab VM)

1. **`git`** clone **`basic_netai`** and **`cd` into it.**

2. **Install Python deps** via **uv**:

   ```bash
   uv sync --all-groups
   ```

3. **Install Ansible collections used by IOS modules** (**no sudo**):

   ```bash
   cd ~/basic_netai/infra/ansible
   uv run ansible-galaxy collection install -r requirements.yml
   ```

Install pulls **`ansible.netcommon`** and **`cisco.ios`** under **`~/.ansible/collections`**, wired by **[`infra/ansible/ansible.cfg`](file:///home/brannen/basic_netai/infra/ansible/ansible.cfg)** (**`collections_path`**).

---

## 4. How Ansible selects devices and merges variables

Four ideas matter.

### Inventory

**[`infra/ansible/inventory/hosts.yml`](file:///home/brannen/basic_netai/infra/ansible/inventory/hosts.yml)** lists routers under group **`csr_lab`** with **`ansible_host:`** pointing at **management** IPv4. Group **`vars`** sets **`ansible_network_os: ios`**.

### Connection

**[`infra/ansible/inventory/group_vars/csr_lab.yml`](file:///home/brannen/basic_netai/infra/ansible/inventory/group_vars/csr_lab.yml)** sets **`ansible_connection: ansible.netcommon.network_cli`**. That unlocks **`cisco.ios.*`** modules. A plain **`ssh`** connection plugin will refuse those tasks with “connection type ssh is not valid”.

### Credentials

Export credentials before running playbooks (same idea as passing a username/password to **`ssh`**), letting Ansible pull them from the environment:

```bash
export CSR_SSH_USERNAME=cisco
export CSR_SSH_PASSWORD='your-password'
```

Group variables **`ansible_user`** / **`ansible_password`** use **`lookup('env', …)`** defaults—see **`inventory/group_vars/csr_lab.yml`**.

### Hierarchy

| Level | Example path | Purpose |
| --- | --- | --- |
| Group | **`inventory/group_vars/csr_lab.yml`** | Anything shared (**syslog collector IP**, connection model). |
| Host | **`inventory/host_vars/csr01.yml`** | Anything unique (**`csr_ospf_router_id`**, Gi1 LAN address). |

Ansible merges them at runtime (**host overrides group**).

---

## 5. Directory tour — `infra/ansible/`

From **[`infra/ansible/`](file:///home/brannen/basic_netai/infra/ansible)**:

| Path | Purpose |
| --- | --- |
| **[`ansible.cfg`](file:///home/brannen/basic_netai/infra/ansible/ansible.cfg)** | **`inventory`** default, Python interpreter, **`host_key_checking=False`** (**lab ergonomics**, not prod policy). |
| **`inventory/`** | Hosts YAML + **`group_vars/`** / **`host_vars/`** (see §4). |
| **`playbooks/`** | Runnable scenarios (**routing**, **logging**, **snapshots**, …). **`playbooks/vars/`** carries shared playbook variables (**for example the IOS capture roster for **`snapshot_configs.yml`**). |
| **`templates/`** | Jinja2 templates rendered into IOS text (**Gi1/OSPF stanza**, **logging** snippets). |
| **`requirements.yml`** | Ansible **Galaxy collection** pinning. |
| **`artifacts/`** | **Local workstation output**, especially **`artifacts/baselines/`** (**gitignored** payload plus tracked **`README.md`**). |

Your **mental map**: **`inventory/`** chooses **targets** & **facts** (**IPs, router-id)**; **`playbooks/`** describe **tasks** against those hosts; **`templates/`** assemble **canonical IOS blobs**.

---

## 6. Typical operational loop (safe rollout)

Operational detail also lives at **[`infra/ansible/README.md`](file:///home/brannen/basic_netai/infra/ansible/README.md)** (**authoritative commands**).

1. **`cd infra/ansible`** (so **`ansible.cfg`** applies).

2. **Dry run**, where IOS modules honour **`ansible-playbook --check`** (read-mostly **`ios_command`** playbooks will not faithfully simulate **`show`** output):

   ```bash
   uv run ansible-playbook playbooks/<scenario>.yml --check --diff
   ```

3. **Apply**:

   ```bash
   uv run ansible-playbook playbooks/<scenario>.yml --diff
   ```

4. **SSH spot-check legacy style** (**`show ip ospf nei`**, **`show run | sec router`**). Automation does not waive final validation.

Patterns in this repo:

| Playbook cluster | Behaviour |
| --- | --- |
| **[`site_routing.yml`](file:///home/brannen/basic_netai/infra/ansible/playbooks/site_routing.yml)** | **`ios_config src=` Gi1/OSPF template** (**idempotent-ish merge**). |
| **[`csr_logging.yml`](file:///home/brannen/basic_netai/infra/ansible/playbooks/csr_logging.yml)** | **`ios_config`** syslog fragment. |
| **[`loopback_redistribute.yml`](file:///home/brannen/basic_netai/infra/ansible/playbooks/loopback_redistribute.yml)** | Incremental IOS lines (**prefix-list, route-map, Lo0 redist**) aligned with **`docs/design/…`**. |
| **[`exec_aliases.yml`](file:///home/brannen/basic_netai/infra/ansible/playbooks/exec_aliases.yml)** | Adds **`alias exec`** shortcuts. |
| **[`snapshot_configs.yml`](file:///home/brannen/basic_netai/infra/ansible/playbooks/snapshot_configs.yml)** | Read-only **`show`** telemetry; artefacts land on controller (**never** merges IOS). |

Certain changes carry **architecture notes** (**peer review**) in **`docs/design/`** before **`--diff`** lands on routers.

---

## 7. How configuration text is authored

Two patterns coexist:

| Pattern | Modules | Best when |
| --- | --- | --- |
| **Template render** | **`cisco.ios.ios_config`** **`src: ../templates/foo.j2`** | Broad stanza rewritten cohesively (**Gi1/OSPF**). Vars substitute **`csr_gi1_ipv4`**, **`csr_ospf_router_id`**, … |
| **Surgical **`lines`** + **`parents`** | **`cisco.ios.ios_config`** (**same**) | Adds child lines (**for example beneath **`router ospf 1`**) without re-rendering entire templates every time |

Engineers migrating manual clips should prefer **narrow **`parents`** scope** (**minimizes blast radius**) **unless intentionally replacing template-driven blocks**.

---

## 8. Baseline snapshots — bridging CLI comfort and tooling

Manual engineers diff **`show run`** outputs. Automated baseline **[`snapshot_configs.yml`](file:///home/brannen/basic_netai/infra/ansible/playbooks/snapshot_configs.yml)** writes **timed folders**:

| Artefact type | Audience | Notes |
| --- | --- | --- |
| **`*.txt` per CSR** | Humans (**`diff -u`**) | Light headers plus verbatim IOS (what seasoned engineers already diff today). |
| **`telemetry.json`** | **`jq`**, Python, LLMs | Mirrors each IOS capture (**`artifact`**, **`command`**, **`ok`**, **`msg`**, **`stdout`**, **`stdout_lines`**, **`capture_format_version`**). |
| **`manifest.json`** | Agents / CI | Host roster + authoritative numbered filenames (**fed from **`vars/baseline_snapshot_commands.yml`**). |

Schema + **`jq` recipes**: **[`infra/ansible/artifacts/baselines/README.md`](file:///home/brannen/basic_netai/infra/ansible/artifacts/baselines/README.md)**.

Operational cautions reiterated:

- **`--check`** skips meaningful collection for **`ios_command`** data paths — **omit for real artefacts**.
- **Avoid careless **`--limit`**** on **`snapshot_configs.yml`** (localhost mints shared snapshot id synchronizing hosts).
- **Secrets** (**local users, SNMP communities**, …**) may reside inside **`running-config`** text — artefacts stay **`gitignored`**.

Think of **`telemetry.json`** like **automated programmatic **`screen logs`** keyed by IOS command.**

---

## 9. Troubleshooting quick matrix

| Symptom | Likely cause | Next step |
| --- | --- | --- |
| **`connection ssh not valid`** | Inventory lost **`ansible_connection: ansible.netcommon.network_cli`** | Confirm **`group_vars`/`host_vars`** sit **inside** **`inventory/`** adjacent **`hosts.yml`**. |
| **Auth failures** | Stale **`CSR_SSH_PASSWORD`** or locked user | Export **`env`** again; **`ssh`** manually (**legacy troubleshooting**). |
| **Dry run discrepancies** | **`--check`** support varies across network modules | Pilot on a disposable lab CSR; treat snapshots as **`--check`-less**. |
| **Ubuntu syslog playbook blocked** | **`sudo-rs`** / missing **`NOPASSWD`** | Prefer **[`infra/syslog/install_receiver.sh`](file:///home/brannen/basic_netai/infra/syslog/install_receiver.sh)** (**see Ansible README**). |
| **Snapshots missing JSON** | Older playbook checkout | **`git pull`**, rerun **`snapshot_configs.yml`** from **`infra/ansible`**. |

---

## 10. Extend / adapt safely — engineer checklist

1. **Locate existing variables** (**host vs group**) before copying literals (**avoid ghost constants** scattered only in templates).
2. **Prefer templated merges** (**re-run idempotency**) vs one-off pasted magic numbers.
3. **Run **`--diff`** on one device first** (**lab scale**: limit carefully—note snapshot caveat).
4. **Write or update **`docs/design/<date>-topic.md`** for policy shifts** (**redistribution**, **BGP**, …)** aligning team review**.
5. **Capture new stable baseline snapshots** (**pre/post change envelopes**).

---

## 11. Where to continue reading

| Document | Topics |
| --- | --- |
| **[`infra/ansible/README.md`](file:///home/brannen/basic_netai/infra/ansible/README.md)** | **Commands**, install, sequencing, syslog caveats. |
| **[`docs/HOW_TO_REPLICATE.md`](HOW_TO_REPLICATE.md)** | **Cold-start** clone + workstation steps. |
| **[`docs/topology.md`](topology.md)** | **IPs & roles** (**physical vs logical**). |
| **[`docs/decisions/README.md`](decisions/README.md)** | **ADRs** explaining **why** (**OSPF choice**, syslog, …). |

Questions about **changing behaviour** (**new routing knobs**) should cite **inventory variables + template + playbook** paths so reviewers can correlate **intent → rendered IOS**.

---

_Last revision: hybrid **`telemetry.json`** + **`manifest.json`** baseline bundles._
