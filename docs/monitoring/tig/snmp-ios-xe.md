# CSR IOS-XE — SNMP for TIGger (lab, Phase A2)

**Scope:** **read-only SNMPv2c** from **TIGger** (`tigger_snmp_collector_ipv4`, currently **`10.0.0.24`**) toward each CSR **management** address in **[`../../../infra/ansible/inventory/hosts.yml`](../../../infra/ansible/inventory/hosts.yml)**. **Production** would lean **SNMPv3**; this lab matches **IOS-XE 16.05.x** reality in **[`../../design/2026-05-10-tigger-TIG-snmp-phased.md`](../../design/2026-05-10-tigger-TIG-snmp-phased.md)**.

## Apply on the routers (Ansible)

From **`infra/ansible/`** with **`CSR_SSH_*`** set (**[`../../../infra/ansible/README.md`](../../../infra/ansible/README.md)**):

```bash
export CSR_SNMP_RO_COMMUNITY='your-lab-read-only-string'
uv run ansible-playbook playbooks/csr_snmp.yml --diff
uv run ansible-playbook playbooks/verify_csr_snmp.yml
```

**`verify_csr_snmp.yml`** runs **`show running-config | include snmp-server`** plus the telemetry ACL (**community strings appear there — do not paste into public chats**).

On the routers directly:

```text
show running-config | include snmp-server
show access-lists BASIC-NETAI-SNMP-TIGGER
```

Use **`show access-lists NAME`** for **named** extended ACLs. **`show ip access-list extended <name>`** is for **numbered** extended ACLs on many IOS-XE images and fails with **`% Invalid input`** if you paste the ACL **name**.

Some images also support **`show snmp community`** — try it if **`include snmp-server`** is empty despite Telegraf/snmpwalk working (**`parser view`** / SNMP-MIB quirks are rare on CSR but possible).

If **`verify_csr_snmp.yml`** shows the **ACL** but **no** **`snmp-server community`** lines: the **global** community stanza never landed (Telegraf cannot poll). Ensure **`csr_snmp.yml`** includes **`ansible.builtin.meta: reset_connection`** **between** the ACL task and **`snmp-server`** (clears rare stuck **`network_cli`** submode); then **`git pull`** and rerun **`csr_snmp.yml --diff`**.

If the playbook still skips **`snmp-server`**, **`show archive config differences`** on the CSR.

The playbook merges:

- **`ip access-list extended BASIC-NETAI-SNMP-TIGGER`** — **`permit udp host <TIGger> any eq snmp`**, **`deny ip any any`**.
- **`snmp-server community <RO> RO BASIC-NETAI-SNMP-TIGGER`**

ACL name and TIGger IP come from **`inventory/group_vars/csr_lab.yml`**. The **community string never lives in Git** — only in **`CSR_SNMP_RO_COMMUNITY`** (Ansible) and **`SNMP_RO_COMMUNITY`** (**`infra/tig/.env`** on TIGger).

**`csr_snmp.yml`** may echo the **`snmp-server community …`** line in **`--diff` / `-v`** output — treat shared logs like secrets.

## Prove reachability before Telegraf

On **TIGger** (after CSR ACL + community):

```bash
SNMP_RO_COMMUNITY='your-lab-read-only-string'
snmpget -v2c -c "$SNMP_RO_COMMUNITY" <CSR_MGMT_IP> 1.3.6.1.2.1.1.5.0
```

Expect **`STRING: "<hostname>"`** (MIB-II **sysName**). **`snmp`** package: **`sudo apt-get install snmp`**.

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

Roughly equivalent to **[`infra/ansible/playbooks/csr_snmp.yml`](../../../infra/ansible/playbooks/csr_snmp.yml)** (preferred) and **`iosxe_snmp_lab.j2`** for hand-paste (**remarks must stay ASCII-only**):

```
configure terminal
ip access-list extended BASIC-NETAI-SNMP-TIGGER
 remark SNMP RO - Tigger telemetry 10.0.0.24
 permit udp host 10.0.0.24 any eq snmp
 deny ip any any
exit
snmp-server community YOUR_RO BASIC-NETAI-SNMP-TIGGER
end
```

Use **`exit`** once after the ACL so you return to **global config** before **`snmp-server`**. A bare **`!`** between stanzas can terminate **configure** on some IOS paths so **`snmp-server` never applies** (you end up with no **`snmp-server`** lines despite a “successful” push).

Adjust **ACL / community** naming if you collide with existing lab config (**`show run | sec snmp`**).

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
