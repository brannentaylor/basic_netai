# Lab topology

ASCII overview (refine after addressing is final):

```text
                 10.0.0.0/24 (management + control)
  +---------------------------+      +---------------------+
  | Ubuntu control VM          |      | CSR01 / CSR02 / CSR03 |
  | - Ansible                  | SSH  | IOS-XE CSR1000v       |
  | - rsyslog UDP/514          |<-----+ mgmt: 10.0.0.20-22   |
  | - uv / network_lab         | logs | Gi1: shared L2 segment |
  +---------------------------+      +----------+------------+
                                                |
                                     192.168.254.0/29 (transit, example)
                                     OSPF area 0 on Gi1 (Ansible converged)
```

**Data plane vs management:** management stays on `10.0.0.0/24` in the starter inventory. **Gi1** carries the routed **OSPF** experiment on **`192.168.254.0/29`** once `site_routing.yml` is applied.

Syslog uses **UDP/514** from CSR → VM; keep the receiver **firewalled** to the lab prefix.
