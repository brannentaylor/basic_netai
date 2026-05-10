# CSR IOS-XE — SNMP for TIGger (lab, Phase A2)

**Scope:** **read-only SNMPv2c** from **TIGger** (`tigger_snmp_collector_ipv4`, currently **`10.0.0.24`**) toward each CSR **management** address in **[`../../../infra/ansible/inventory/hosts.yml`](../../../infra/ansible/inventory/hosts.yml)**. **Production** would lean **SNMPv3**; this lab matches **IOS-XE 16.05.x** reality in **[`../../design/2026-05-10-tigger-TIG-snmp-phased.md`](../../design/2026-05-10-tigger-TIG-snmp-phased.md)**.

## Apply on the routers (Ansible)

From **`infra/ansible/`** with **`CSR_SSH_*`** set (**[`../../../infra/ansible/README.md`](../../../infra/ansible/README.md)**):

```bash
export CSR_SNMP_RO_COMMUNITY='your-lab-read-only-string'
uv run ansible-playbook playbooks/csr_snmp.yml --diff
uv run ansible-playbook playbooks/verify_csr_snmp.yml
```

**`verify_csr_snmp.yml`** uses **`show ip access-list <n>`** (**`csr_snmp_standard_acl_num`**, default **`87`**) plus a full **`show running-config`** probe and asserts **`snmp-server community`** in the flattened text. Do not trust **`show run | inc snmp-server`** alone from **Ansible** on some transports. **Do not paste blobs** with communities into public chats.

On the routers directly:

```text
show running-config | include snmp-server
show ip access-list 87
```

**`csr_snmp.yml`** uses a **numbered STANDARD** ACL (**`access-list 87 permit host <TIGger>`**) and **`snmp-server community "…" RO 87`**. That path avoids CSR1000v **`could not be allocated / incompatible type`** failures seen when binding **`snmp-server … RO <named extended ACL>`** on some units. Prelude is still **destructive**: **`no snmp-server`**, **`no access-list 87`**, and best-effort removal of **named** ACL leftovers (**`csr_snmp_acl_name`**, **`BASIC-NETAI-SNMP-TIGGER`**).

If **`87`** clashes with another lab use of **`access-list 87`**, set **`csr_snmp_standard_acl_num`** in **`group_vars/csr_lab.yml`** to a free **`1–99`** slot.

**Important:** **`group_vars` file name must stay** **`csr_lab.yml`** — it must match inventory group **`csr_lab`**. Only change **`csr_snmp_standard_acl_num`** / **`csr_snmp_acl_name`** keys inside it, never the filename.

If IOS still rejects the line, inspect **`show archive config differences`** / **`snmp mib`** or paste redacted **`% …`** banners from Ansible (not secrets).

The playbook installs:

- **`access-list <n> permit host <TIGger-ip>`** (standard numbered; default **`n=87`**).
- **`snmp-server community <RO> RO <n>`**

**`<n>`**, **Tigger IP**, and legacy named-ACL purge labels live in **`inventory/group_vars/csr_lab.yml`**. The **community string never lives in Git** — **`CSR_SNMP_RO_COMMUNITY`** (Ansible) and **`SNMP_RO_COMMUNITY`** on TIGger (**`infra/tig/.env`**).

**`csr_snmp.yml`** may echo the **`snmp-server community …`** line in **`--diff` / `-v`** output — treat shared logs like secrets.

## Prove reachability before Telegraf

On **TIGger** (after CSR ACL + community). Install **`snmpget`** once: **`sudo apt-get install snmp`**.

Use a **literal management IP**. In **`bash`**, a line like `snmpget ... <mgmt_ip>` treats **`<mgmt_ip>`** as **stdin from a file**, so you see **`No such file or directory`** if you paste the placeholder:

```bash
SNMP_RO_COMMUNITY='your-lab-read-only-string'
snmpget -v2c -c "$SNMP_RO_COMMUNITY" 10.0.0.22 1.3.6.1.2.1.1.5.0
```

Use any **`csr_lab`** **`ansible_host`** from **`hosts.yml`** (example IPs in this repo: **`10.0.0.20`**, **`10.0.0.22`**, **`10.0.0.23`** — confirm yours).

Expect **`STRING: "hostname"`** (MIB-II **sysName**, e.g. **`r2.homelab.com`**).

If this times out — fix **routing** (TIGger → **`ansible_host`**) before blaming Telegraf.

## Telegraf

**[`../../../infra/tig/install_telegraf_snmp_csr.sh`](../../../infra/tig/install_telegraf_snmp_csr.sh)** parses the same **`hosts.yml`** and writes **`/etc/telegraf/telegraf.d/96-snmp-csr.conf`** plus **`EnvironmentFile`** **`snmp_lab.env`**. Requires **`python3-yaml`** (script installs **`python3-yaml`** via APT if missing).

Flux example (**`YOUR_BUCKET`** = your **`INFLUX_BUCKET`**):

```flux
from(bucket: "YOUR_BUCKET")
  |> range(start: -30m)
  |> filter(fn: (r) => r._measurement == "csr_snmp")
  |> limit(n: 20)
```

## Manual IOS reference (same as template)

Hand-paste mirror: **[`infra/ansible/templates/iosxe_snmp_lab.j2`](../../../infra/ansible/templates/iosxe_snmp_lab.j2)** (or run **`csr_snmp.yml`**). Uses a **numbered standard ACL** (**default 87**) and **`snmp-server community … RO 87`**.

## Troubleshooting Ansible

### `host key mismatch for <ansible_host>`

Paramiko (used when **`ansible-pylibssh`** is not installed) still errors if **`~/.ssh/known_hosts`** has an **older** key for that CSR. Remove the stale entry, then rerun:

```bash
ssh-keygen -R 10.0.0.20    # csr01 ansible_host — repeat per router IP if needed
```

The repo dev group includes **`ansible-pylibssh`** — install collections + sync from the repo root:

```bash
cd ~/basic_netai && uv sync --all-groups
cd infra/ansible && uv run ansible-galaxy collection install -r requirements.yml
```

After that, **`ansible-pylibssh`** is available to **network_cli** and the “falling back to paramiko” warning usually goes away.

### `% Invalid input detected` on `remark ...`

Usually **non-ASCII punctuation** copied into **`remark`** (smart quotes, em dashes). Template lines pushed to IOS must be **ASCII** only — use **`-`** not **`—`** in remarks.

### Ansible deprecation: template `src` on **`ios_config`**

The lab **`csr_snmp.yml`** play uses **`lines`/`parents`** (no **`src`** blob), so that warning should not occur for SNMP apply. Vendor guidance still evolves toward **`template`**-friendly pipelines — watch **ansible.netcommon** / **cisco.ios** release notes.
