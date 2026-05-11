# OSPF neighbor down (triangle + Gi4 cloud)

## Symptom

`show ip ospf neighbor` missing an expected adjacency on a **triangle** leg.

## Lab topology (Ansible default)

| Link | Endpoints |
| --- | --- |
| **R1–R2** | **csr01 Gi1** ↔ **csr02 Gi1** (`10.0.12.0/24`) |
| **R2–R3** | **csr02 Gi2** ↔ **csr03 Gi2** (`10.0.23.0/24`) |
| **R1–R3** | **csr01 Gi3** ↔ **csr03 Gi3** (`10.0.13.0/24`) |
| **Cloud** | **csr01/02/03 Gi4** on **`10.0.0.0/24`** (**OSPF passive** — no neighbors expected on Gi4; same /24 as syslog/TIGger) |

## Quick checks (CSR CLI)

- `show ip ospf interface brief` — triangle interfaces **not passive**; **Gi4** **passive** for cloud.
- `show ip ospf neighbor detail`
- `show interfaces` for each triangle **Gi** — line protocol **up**?

## Lab-specific

- **Wrong cable** vs **`csr_ospf_interfaces`** in **`host_vars`**.
- Mismatched **IP / mask** on a `/24` leg.
- After migrating from older **`192.168.254.*`** designs, **`no network 192.168.254.0 0.0.0.7 area 0`** ( **`site_routing.yml`** best-effort) should have run.

## Ansible-side

- `uv run ansible-playbook playbooks/site_routing.yml --diff`
- Compare running config to **`infra/ansible/templates/iosxe_triangle_ospf.j2`**.

## Legacy Gi1 /29

Rollback (only if needed): **`templates/iosxe_gi1_ospf_legacy_broadcast.j2`** + old **`csr_gi1_*`** vars — not compatible with current triangle vars; restore from Git history if required.
