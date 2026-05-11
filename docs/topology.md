# Lab topology

**Naming:** diagram **CSR1 / CSR2 / CSR3** = inventory **`csr01` / `csr02` / `csr03`**. **Net** = shared lab **`10.0.0.0/24`** (each router **Gi4** into the cloud; syslog, TIGger, Ansible on that segment per **`docs/ip-plan.md`**).

### Triangle + cloud (peer / interface chart)

| Local router | Local interface | Remote peer | Remote interface |
| --- | --- | --- | --- |
| **CSR1** | Gi1 | CSR2 | Gi1 |
| **CSR1** | Gi3 | CSR3 | Gi3 |
| **CSR1** | Gi4 | Net (`10.0.0.0/24`) | (L2 segment) |
| **CSR2** | Gi1 | CSR1 | Gi1 |
| **CSR2** | Gi2 | CSR3 | Gi2 |
| **CSR2** | Gi4 | Net (`10.0.0.0/24`) | (L2 segment) |
| **CSR3** | Gi2 | CSR2 | Gi2 |
| **CSR3** | Gi3 | CSR1 | Gi3 |
| **CSR3** | Gi4 | Net (`10.0.0.0/24`) | (L2 segment) |

IPs and masks: **`infra/ansible/inventory/host_vars/csr0{1,2,3}.yml`** + **`site_routing.yml`**.

---

ASCII overview (refine after addressing is final):

```text
                 10.0.0.0/24 (lab cloud — syslog, TIGger, Ansible targets on Gi4)
  +---------------------------+      +---------------------+
  | Ubuntu control VM          |      | CSR01 / CSR02 / CSR03 |
  | - Ansible                  | SSH  | IOS-XE CSR1000v       |
  | - rsyslog UDP/514          |<-----+ Gi4: 10.0.0.20/25/22  |
  | - uv / network_lab         | logs | (ansible_host)        |
  +---------------------------+      +----------+------------+
                                                |
        10.0.12.0/24   csr01 Gi1 <-----> csr02 Gi1
        10.0.23.0/24   csr02 Gi2 <-----> csr03 Gi2
        10.0.13.0/24   csr01 Gi3 <-----> csr03 Gi3
        (OSPF area 0 triangle; Gi4 OSPF passive — site_routing.yml)
```

**Data plane vs management:** **`site_routing.yml`** builds **OSPF area 0** on the **triangle** (**`10.0.12.0/24`**, **`10.0.23.0/24`**, **`10.0.13.0/24`**) and **`10.0.0.0/24`** on each CSR **`GigabitEthernet4`** (**`ip ospf 1 area 0`**, **OSPF passive**). **Gi4** addresses match **`ansible_host`** in **`inventory/hosts.yml`** so **syslog** (**`lab_syslog_collector_ipv4`**) and **SNMP** (**TIGger**) on **`10.0.0.0/24`** stay reachable without extra routing tricks.

Syslog uses **UDP/514** from CSR → VM; keep the receiver **firewalled** to the lab prefix.
