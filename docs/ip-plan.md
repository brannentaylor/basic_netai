# IP plan (authoritative — update with reality)

| Role | Prefix / host | Notes |
| --- | --- | --- |
| Lab cloud + mgmt (Gi4) | `10.0.0.0/24` | **csr01 Gi4** `10.0.0.20`, **csr02 Gi4** `10.0.0.25`, **csr03 Gi4** `10.0.0.22` — matches **`ansible_host`** in **`hosts.yml`** |
| OSPF triangle R1–R2 | `10.0.12.0/24` | **csr01 Gi1** `.1`, **csr02 Gi1** `.2` |
| OSPF triangle R2–R3 | `10.0.23.0/24` | **csr02 Gi2** `.2`, **csr03 Gi2** `.3` |
| OSPF triangle R1–R3 | `10.0.13.0/24` | **csr01 Gi3** `.1`, **csr03 Gi3** `.3` |
| Syslog collector | `lab_syslog_collector_ipv4` in `inventory/group_vars/csr_lab.yml` | **`10.0.0.21`** in starter files |
| TIGger SNMP source | `tigger_snmp_collector_ipv4` | **`10.0.0.24`** |

| Hostname | Router ID | Triangle + Gi4 (see `host_vars`) | `ansible_host` |
| --- | --- | --- | --- |
| csr01 | 1.1.1.1 | Gi1 `.1/24`, Gi3 `.1/24`, Gi4 `10.0.0.20/24` | `10.0.0.20` |
| csr02 | 2.2.2.2 | Gi1 `.2/24`, Gi2 `.2/24`, Gi4 `10.0.0.25/24` | `10.0.0.25` |
| csr03 | 3.3.3.3 | Gi2 `.3/24`, Gi3 `.3/24`, Gi4 `10.0.0.22/24` | `10.0.0.22` |

**Cabling:** **csr01 Gi1↔csr02 Gi1**, **csr02 Gi2↔csr03 Gi2**, **csr01 Gi3↔csr03 Gi3**; **Gi4** on each CSR to shared **lab cloud** **`10.0.0.0/24`**.

### Physical vs Ansible (when things feel swapped)

You have **three naming layers**; only one row on each chassis should be true:

| Rack / diagram | Ansible inventory host | IOS `hostname` (goal) | SSH / Ansible **`ansible_host`** (Gi4) | OSPF **router-id** (Loopback0 goal) |
| --- | --- | --- | --- | --- |
| R1 | `csr01` | `csr01` | `10.0.0.20` | `1.1.1.1` |
| R2 | `csr02` | `csr02` | `10.0.0.25` | `2.2.2.2` |
| R3 | `csr03` | `csr03` | `10.0.0.22` | `3.3.3.3` |

**Rule:** **`ansible_host`** in **`hosts.yml`** is always **that router’s Gi4 address** on **`10.0.0.0/24`**. It must equal **`csr_ospf_interfaces`** Gi4 **`ipv4`** in **`host_vars/<same host>.yml`**. If you SSH to **`10.0.0.25`**, you must be on **csr02** (R2), not csr03.

**Un-mangle the lab (order matters):**

1. **Console** (or SSH if you already know who is who) each physical router and capture **`hostname`**, **`show ip interface brief`**, **`show ip ospf interface brief`** (or `show run | sec router ospf`).
2. **Match** the output to **one row** in the table above (Gi4 + router-id + triangle addresses are the fingerprint: csr01 has **Gi1+Gi3** transit, csr02 **Gi1+Gi2**, csr03 **Gi2+Gi3** — see the second table in this file).
3. For each chassis whose **fingerprint** does not match its **physical** R1/R2/R3 role, run **`site_routing.yml`** with **`--limit csr01`** / **`csr02`** / **`csr03`** for the role that chassis **should** play. If Gi4 still has the **wrong** IP so inventory would miss, use a **one-shot** reachability override, e.g. **`ansible-playbook ... --limit csr03 -e ansible_host=<current Gi4>`** until Gi4 matches **`hosts.yml`**.
4. **csr03 only:** **`site_routing`** does not configure **Gi1**. If Gi1 ever had **csr02-style** **`10.0.12.2`**, run **`default interface GigabitEthernet1`** (or shut + remove IP) on **csr03** after the playbook.
5. Re-check from the **control host**: ping **`10.0.0.20`**, **`.25`**, **`.22`**, then **`ansible csr_lab -m ping`**.

**Master data warning:** keep this table aligned with **`infra/ansible/inventory`** (`hosts.yml`, **`group_vars/`**, **`host_vars/`**) and **`src/network_lab/inventory/*.yaml`**.

**Legacy:** old Gi1 **`/29`** + **`192.168.254.*`** triangle superseded; **`templates/iosxe_gi1_ospf_legacy_broadcast.j2`** kept for emergency rollback only.
