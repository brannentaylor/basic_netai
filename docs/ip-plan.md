# IP plan (authoritative — update with reality)

| Role | Prefix / host | Notes |
| --- | --- | --- |
| Management + control | `10.0.0.0/24` | Ubuntu VM + CSR mgmt in starter files |
| Gi1 OSPF transit | `192.168.254.0/29` | Example from Ansible `host_vars` |
| Syslog collector | `lab_syslog_collector_ipv4` in `group_vars/csr_lab.yml` | Set to your VM address |

| Hostname | Router ID | Gi1 address (example) | Mgmt address |
| --- | --- | --- | --- |
| csr01 | 1.1.1.1 | 192.168.254.1/29 | 10.0.0.20 |
| csr02 | 2.2.2.2 | 192.168.254.2/29 | 10.0.0.21 |
| csr03 | 3.3.3.3 | 192.168.254.3/29 | 10.0.0.22 |

**Master data warning:** keep this table aligned with `infra/ansible/inventory`, `infra/ansible/host_vars`, and `src/network_lab/inventory/*.yaml`.
