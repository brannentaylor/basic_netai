# IP plan (authoritative — update with reality)

| Role | Prefix / host | Notes |
| --- | --- | --- |
| Management + control | `10.0.0.0/24` | Ubuntu VM + CSR mgmt in starter files |
| Gi1 OSPF transit | `192.168.254.0/29` | Example from Ansible `inventory/host_vars/` |
| Syslog collector | `lab_syslog_collector_ipv4` in `inventory/group_vars/csr_lab.yml` | **`10.0.0.21`** — this Ubuntu VM (do not collide with CSR mgmt IPs) |

| Hostname | Router ID | Gi1 address (example) | Mgmt address |
| --- | --- | --- | --- |
| csr01 | 1.1.1.1 | 192.168.254.1/29 | 10.0.0.20 |
| csr02 | 2.2.2.2 | 192.168.254.2/29 | 10.0.0.23 |
| csr03 | 3.3.3.3 | 192.168.254.3/29 | 10.0.0.22 |

**Master data warning:** keep this table aligned with **`infra/ansible/inventory`** (`hosts.yml`, **`group_vars/`**, **`host_vars/`**) and **`src/network_lab/inventory/*.yaml`**.
