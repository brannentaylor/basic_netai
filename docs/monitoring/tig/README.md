# TIG on TIGger (Telegraf + InfluxDB + Grafana)

## Where this stack runs

Install **Telegraf**, **InfluxDB 2**, and **Grafana** on a **separate Ubuntu server** named **TIGger** — **not** on the same VM as the **Ansible / syslog collector** (`lab_syslog_collector_ipv4` on **`10.0.0.0/24`** in **[`../../../infra/ansible/README.md`](../../../infra/ansible/README.md)**). Metrics collection and dashboards live only on **TIGger**; CSR **`logging host`** syslog stays on the existing receiver until you merge pipelines on purpose (**[`../syslog.md`](../syslog.md)**).

**This lab:** **TIGger** management IPv4 is **`10.0.0.24`** (confirm with `ip -br a` / your inventory if it changes).

Operational hub for metrics on that host. Design reference: **[`../../design/2026-05-10-tigger-TIG-snmp-phased.md`](../../design/2026-05-10-tigger-TIG-snmp-phased.md)**.

TIGger uses the **same** repository as the rest of the lab (**`basic_netai`**). Develop on **`ubba`**, **`git push`** from there; on **TIGger** you only need **read** access to **`git pull`** the latest **`infra/tig/`** and docs.

## Clone the repo on TIGger

Do this once before **`Phase A0`** on **TIGger** so scripts are available under **`infra/tig/`**.

1. **Outbound network:** **TIGger** must reach **GitHub** over **HTTPS (443)** — usual default-allow egress is enough (**`ufw`** does not block outbound by default).

2. **SSH (recommended)**  
   - Generate a key on **TIGger** (example):  
     `ssh-keygen -t ed25519 -C "tigger-basic_netai" -f ~/.ssh/id_ed25519_tigger`  
   - In the GitHub repo: **Settings → Deploy keys → Add deploy key**. Paste **`~/.ssh/id_ed25519_tigger.pub`**. Leave **Allow write access** **unchecked** — read-only is enough for **`clone` / `pull`**.  
   - If the key is **not** the default **`~/.ssh/id_ed25519`**, add **`~/.ssh/config`** on **TIGger**:  
     ```text
     Host github.com
       IdentityFile ~/.ssh/id_ed25519_tigger
       IdentitiesOnly yes
     ```  
   - Test: **`ssh -T git@github.com`** (success / “Hi …!”).  
   - Clone (adjust user/org to match **[`../../HOW_TO_REPLICATE.md`](../../HOW_TO_REPLICATE.md)**):  
     `git clone git@github.com:brannentaylor/basic_netai.git`  
     Use a directory you keep (e.g. **`~/basic_netai`**). Run **`infra/tig/`** scripts from the repo root when docs say **`sudo bash infra/tig/...`**.

3. **Updates:** **`cd basic_netai && git pull`** before re-running installers or changing stack configs.

4. **HTTPS (alternative):**  
   `git clone https://github.com/brannentaylor/basic_netai.git` — use a **credential helper** or **fine-grained PAT** for pulls. **Never** store tokens inside the cloned tree or commit them.

5. **Pushing:** Commits and **`git push`** stay on **`ubba`** (or another host with write access). To push from **TIGger** you would need a **different** credential path (user SSH key with write, or PAT); not required to operate the TIG stack.

## Ports (listen expectations)

| Service | Port | Notes |
| --- | --- | --- |
| **SSH** | **22/tcp** | Administrative access; keep allowed before tightening **ufw**. |
| **Grafana** | **3000/tcp** | Web UI — restrict to lab CIDR or **SSH tunnel** only (Phase A0). |
| **InfluxDB 2 HTTP API** | **8086/tcp** | Writes/queries — same restriction as Grafana (Phase A0 / A1). |
| **SNMP poll (CSR → Telegraf direction)** | **161/udp** on **CSR** | Telegraf on TIGger polls **toward** CSR management IPs (Phase A2); CSR **ACL** must allow **only TIGger** as source. |

## Phase checklist (SNMP Path A)

| Phase | Outcome | Repo / notes |
| --- | --- | --- |
| **A0** | **chrony** (time sync); **ufw** — SSH allowed; **3000** / **8086** from lab CIDR or tunnel only | **`infra/tig/`** scripts + **`dotenv.example`** |
| **A1** | InfluxDB 2 org + bucket; API token (**never committed**); Grafana install | **`install_influxdb2.sh`**, **`install_grafana.sh`**; token in **`.env`** only |
| **A1-smoke** | **Telegraf** on **TIGger** writes **localhost** **cpu/mem** → **`lab-bucket`** — proves Grafana **Explore + Flux + Influx pipeline** before SNMP | **`install_telegraf_smoke.sh`** |
| **A2** | CSR `snmp-server` + ACL; TIGger **Telegraf** `inputs.snmp` → Influx | Inventory CSRs in **[`infra/ansible/inventory/hosts.yml`](../../../infra/ansible/inventory/hosts.yml)** |
| **A3** | Grafana datasource + starter dashboards | — |
| **A4 (optional)** | **inputs.ping**, syslog bridge | — |

## SNMP vs gNMI (lab reality)

| Path | When | CSR requirement |
| --- | --- | --- |
| **SNMP** (preferred **now**) | Phase A2+ | **IOS-XE 16.05.x** — practical poll path (**v3** preferred or **v2c** with ACL) |
| **gNMI / model-driven telemetry** | Phase B (deferred) | **≥ ~16.11 / 17.x** — see design doc gate; no router changes until upgrade |

## Phase A0 — run order on TIGger

Prerequisite: **clone / pull** the repo on **TIGger** (**[`Clone the repo on TIGger`](#clone-the-repo-on-tigger)**).

### What **`infra/tig/.env`** is

- A **small settings file on TIGger only** — a copy of **`dotenv.example`** you edit. It is **`gitignore`d**, so it **never gets committed** (good place for later **Influx** tokens).
- **`install_ufw_tig.sh`** reads **`infra/tig/.env`** at the **top of your clone** (same level as **`docs/`** and **`infra/`**) to learn which network may reach Grafana (**3000**) and Influx (**8086**). If **`.env`** is missing or **`TIG_LAB_ALLOW_CIDR`** is unset, the ufw step fails until you fix it.

### Steps

SSH to **TIGger**, go to the repo root (where **`infra/`** and **`docs/`** sit), e.g.:

```bash
cd ~/basic_netai
```

**1 — Create `infra/tig/.env` (once):**

```bash
cp infra/tig/dotenv.example infra/tig/.env
```

Edit **`infra/tig/.env`** with any editor and ensure this line matches your lab (management LAN that should reach **TIGger’s** web UIs):

```bash
TIG_LAB_ALLOW_CIDR=10.0.0.0/24
```

Meaning in plain language: “only hosts in **`10.0.0.0/24`** may connect to **TCP 3000** and **8086** on **TIGger** once **`ufw`** is enabled; **SSH** from anywhere is still allowed as written in the script.” Your workstation must sit in that range **or** you use **SSH port-forwarding** instead of browsing from another subnet.

**2 — Chrony:** **`sudo bash infra/tig/install_chrony.sh`**

**3 — UFW rules (review, then enable):** **`sudo bash infra/tig/install_ufw_tig.sh`** — then run **`sudo ufw enable`** when the printed rules look right (script reminds you).

**Safety:** read-only SNMP on the wire from automation; trust boundaries in **`docs/agent-ops/safety.md`**.

## Phase A1 — InfluxDB 2 + Grafana on TIGger

Run from the **repo root** on **TIGger** (e.g. **`cd ~/basic_netai`**), after **`git pull`**.

Prerequisites: **`Phase A0`** complete so **`ufw`** allows **SSH** and **8086** / **3000** from **`TIG_LAB_ALLOW_CIDR`** (`10.0.0.0/24`).

1. **`sudo bash infra/tig/install_influxdb2.sh`** — APT repo + **`influxdb2`** package, enable **`influxdb`** service. **If APT reports 404** for **`repos.influxdata.com/ubuntu`** with your release codename, you are probably on a **very new** Ubuntu: **`git pull`** the repo (script falls back to **Debian stable**) or see **[`../../design/2026-05-10-tigger-TIG-snmp-phased.md`](../../design/2026-05-10-tigger-TIG-snmp-phased.md)** — the installer prints **`Note: using InfluxData debian stable channel…`** when it uses the fallback.
2. **First-time Influx setup** (interactive), as a normal user on **TIGger** (not root): **`influx setup`** — org name, bucket (e.g. **`csr_metrics`**), admin user/password, then **retention in hours only**: type **`720`** for 30 days, **`0`** for infinite — **`720h`** will error (`strconv.Atoi`). Copy the **`token`** printed at the end.
3. Edit **the same file** **`infra/tig/.env`** you created in **A0** (still on **TIGger**). Add the Influx lines from **`dotenv.example`**: **`INFLUX_URL`**, **`INFLUX_ORG`**, **`INFLUX_BUCKET`**, **`INFLUX_TOKEN`** (paste the token **`influx setup`** printed). Still **never commit** **`infra/tig/.env`**.
4. **`sudo bash infra/tig/install_grafana.sh`** — Grafana OSS; first visit to **`http://10.0.0.24:3000/`** (from **`10.0.0.0/24`**) or **`ssh -L 3000:127.0.0.1:3000 tigger`** then **`http://127.0.0.1:3000`** sets the Grafana admin password.
5. **Verify:** **`systemctl status influxdb`**, **`systemctl status grafana-server`**, **`curl -fsS http://127.0.0.1:8086/health`**, **`ss -tlnp | grep -E ':8086|:3000'`**.

**Phase A3** adds the Grafana **InfluxDB** datasource and dashboards; you can add the datasource early using the token from **`.env`** if you prefer.

### Phase A1-smoke — Telegraf localhost metrics

**Goal:** see **non-zero** rows in Grafana **Explore** — same path **Telegraf** will use later for SNMP (**`outputs.influxdb_v2`**).

Prerequisites: **`infra/tig/.env`** on **TIGger** has **`INFLUX_ORG`**, **`INFLUX_BUCKET`**, **`INFLUX_TOKEN`** (no quotes).

1. From repo root: **`sudo bash infra/tig/install_telegraf_smoke.sh`** (re-run anytime; **APT does not reinstall** if already current).
   - Writes **`/etc/telegraf/telegraf.d/99-smoke-local.conf`** with **`outputs.influxdb_v2`** **`token = "${INFLUX_TOKEN}"`** (Telegraf **≥1.38** rejects **`token_file`** on that plugin). Injects the token via **`/etc/telegraf/influx_smoke.env`** + **`EnvironmentFile=`** under **`telegraf.service.d/basic-netai-smoke.conf`**, **and replaces `ExecStart`** so it no longer ends in **`$TELEGRAF_OPTS`** (unset **`TELEGRAF_OPTS`** caused **Telegraf exit 1** via an empty trailing argv on some systemd versions).
   - If **`/etc/telegraf/telegraf.conf`** fails to parse (**`invalid TOML`** from an earlier edit), the script **backs it up** and restores the **packaged** **`telegraf.conf`** (from **`examples/telegraf.conf.gz`** if present, otherwise from the **`telegraf`** **`.deb`**).
   - Debian-style units load **every** **`*.conf`** under **`telegraf.d`**. The installer removes legacy **`smoke-local.conf`** / **`smoke-local.toml`** (old **`token_file`** snippets); the active file is **`99-smoke-local.conf`**. Legacy **`@include`** footer in **`telegraf.conf`** is stripped if still present.
2. **`systemctl status telegraf`** — should be **active**. If errors: **`journalctl -u telegraf -n 50 --no-pager`** (401 → token/org/bucket; permission → **`chgrp telegraf`** on **`influx_token`**).
3. **Grafana → Explore**, same Influx datasource, **Flux** (wait ~60s):

   ```flux
   from(bucket: "lab-bucket")
     |> range(start: -15m)
     |> filter(fn: (r) => r._measurement == "cpu")
     |> limit(n: 5)
   ```

   Use **`your`** bucket string if different from **`lab-bucket`**.
4. If you already had **`[[inputs.cpu]]`** enabled in **`/etc/telegraf/telegraf.conf`**, **cpu** might appear duplicated — for smoke that is harmless; tighten later.

## Phase A2 — CSR SNMP (Ansible routers + Telegraf on TIGger)

**Goal:** **`csr_snmp`** measurements in Grafana (**sysName**, **sysUpTime**) polled from **TIGger** to each CSR **`ansible_host`**.

### 1 — Routers (from control node with Ansible)

Uses **[`infra/ansible/playbooks/csr_snmp.yml`](../../../infra/ansible/playbooks/csr_snmp.yml)** (**`ios_config` `lines`/`parents`**, not a monolithic **`src`** file). **[`iosxe_snmp_lab.j2`](../../../infra/ansible/templates/iosxe_snmp_lab.j2)** is a **hand-paste mirror** only. Vars **`tigger_snmp_collector_ipv4`**, **`csr_snmp_acl_name`**: **`inventory/group_vars/csr_lab.yml`**.

Dry-run optional:

```bash
cd ~/basic_netai/infra/ansible
export CSR_SSH_USERNAME=cisco CSR_SSH_PASSWORD='…'
export CSR_SNMP_RO_COMMUNITY='your-lab-read-only-string'
uv run ansible-playbook playbooks/csr_snmp.yml --check --diff
uv run ansible-playbook playbooks/csr_snmp.yml --diff
uv run ansible-playbook playbooks/verify_csr_snmp.yml
```

**`verify_csr_snmp.yml`** prints **`running-config | include snmp-server`** and **`show access-lists <acl-name>`** per CSR (**community strings are visible — lab terminal only**).

Use the **same** read-only community string locally on **TIGger** (next step).

### 2 — Prove SNMP from TIGger

```bash
sudo apt-get install -y snmp
SNMP_RO_COMMUNITY='your-lab-read-only-string'
snmpget -v2c -c "$SNMP_RO_COMMUNITY" 10.0.0.20 1.3.6.1.2.1.1.5.0
```

(Replace **`10.0.0.20`** with any **`csr_lab`** management IP.)

### 3 — Telegraf fragment + env (on TIGger repo root)

1. **`infra/tig/.env`** — add **`SNMP_RO_COMMUNITY=…`** (**[`dotenv.example`](../../../infra/tig/dotenv.example)**).
2. **`sudo bash infra/tig/install_telegraf_snmp_csr.sh`**

Installer writes **`/etc/telegraf/telegraf.d/96-snmp-csr.conf`** from **`infra/ansible/inventory/hosts.yml`**, **`/etc/telegraf/snmp_lab.env`**, and **`telegraf.service.d/snmp-lab-env.conf`**. It installs **`python3-yaml`** via APT when needed.

Re-run **`install_telegraf_snmp_csr.sh`** after **`hosts.yml`** changes.

### 4 — Grafana Explore (Flux)

```flux
from(bucket: "YOUR_BUCKET")
  |> range(start: -30m)
  |> filter(fn: (r) => r._measurement == "csr_snmp")
  |> limit(n: 15)
```

**Reference:** **`snmp-ios-xe.md`**, **`../../design/2026-05-10-tigger-TIG-snmp-phased.md`**.

## Related docs

| Doc | Purpose |
| --- | --- |
| **`snmp-ios-xe.md`** | CSR `snmp-server`, **`snmpget`**, Telegraf fragment notes |
| **`gnmi-roadmap.md`** | Phase B gate (no gNMI until IOS upgrade) |
