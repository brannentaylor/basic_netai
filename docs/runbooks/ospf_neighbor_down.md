# OSPF neighbor down (Gi1)

## Verify

```text
show ip ospf neighbor
show ip interface brief | include GigabitEthernet1
show interfaces GigabitEthernet1
```

## Common causes

- Gi1 shutdown or cabling/L2 loss on the shared segment.
- Mismatched subnet / mask (`192.168.254.0/29` lab default).
- Muted interface in OSPF (`passive-interface` misconfiguration).
- ACL blocking multicast/broadcast on the segment.

## Recovery pointers

- From `infra/ansible/`, re-run `uv run ansible-playbook playbooks/site_routing.yml` after fixing variables.
- Compare running config to `infra/ansible/templates/iosxe_gi1_ospf.j2`.
