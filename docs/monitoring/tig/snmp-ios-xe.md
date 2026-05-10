# CSR IOS-XE — SNMP for TIGger (lab, Phase A2)

**Scope:** **read-only SNMPv2c** from **TIGger** (`tigger_snmp_collector_ipv4`, currently **`10.0.0.24`**) toward each CSR **management** address in **[`../../../infra/ansible/inventory/hosts.yml`](../../../infra/ansible/inventory/hosts.yml)**. **Production** would lean **SNMPv3**; this lab matches **IOS-XE 16.05.x** reality in **[`../../design/2026-05-10-tigger-TIG-snmp-phased.md`](../../design/2026-05-10-tigger-TIG-snmp-phased.md)**.

## Apply on the routers (Ansible)

From **`infra/ansible/`** with **`CSR_SSH_*`** set (**[`../../../infra/ansible/README.md`](../../../infra/ansible/README.md)**):

```bash
export CSR_SNMP_RO_COMMUNITY='your-lab-read-only-string'
uv run ansible-playbook playbooks/csr_snmp.yml --diff
```

The playbook merges:

- **`ip access-list extended BASIC-NETAI-SNMP-TIGGER`** — **`permit udp host <TIGger> any eq snmp`**, **`deny ip any any`**.
- **`snmp-server community <RO> RO BASIC-NETAI-SNMP-TIGGER`**

ACL name and TIGger IP come from **`inventory/group_vars/csr_lab.yml`**. The **community string never lives in Git** — only in **`CSR_SNMP_RO_COMMUNITY`** (Ansible) and **`SNMP_RO_COMMUNITY`** (**`infra/tig/.env`** on TIGger).

`ios_config` is logged with **`no_log: true`** so the literal community should not spray into Ansible stdout (still assume lab-only secrets).

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

Roughly equivalent to **[`infra/ansible/templates/iosxe_snmp_lab.j2`](../../../infra/ansible/templates/iosxe_snmp_lab.j2)**:

```
ip access-list extended BASIC-NETAI-SNMP-TIGGER
 remark SNMP RO — only telemetry host 10.0.0.24
 permit udp host 10.0.0.24 any eq snmp
 deny ip any any
exit
snmp-server community YOUR_RO BASIC-NETAI-SNMP-TIGGER
```

Adjust **ACL / community** naming if you collide with existing lab config (**`show run | sec snmp`**).
