# No syslog from router X

## Verify on CSR

```text
show logging
show run | include logging
```

## Verify on Ubuntu VM

```bash
sudo ss -ulnp | grep 514 || true
sudo tail -n 50 /var/log/network-lab/all.log
# Network-heavy view (patterns from inventory hostname / mgmt IPs):
sudo grep -Ei 'csr0|10\.0\.0\.(20|22|23)' /var/log/network-lab/all.log | tail -n 50
```

See **`docs/monitoring/syslog.md`** if **`all.log` contains Ubuntu OS noise**: reinstall the **`ruleset`-bound **`imudp`** fragment and restart **`rsyslog`**.

## Common causes

- Wrong **`lab_syslog_collector_ipv4`** in `infra/ansible/inventory/group_vars/csr_lab.yml`.
- **UFW** / host firewall blocking UDP/514 from `10.0.0.0/24`.
- **`logging source-interface`** pointing at an interface that cannot reach `10.0.0.0/24` (leave blank in `inventory/group_vars` to let IOS decide).
- rsyslog not restarted after editing `/etc/rsyslog.d/`.

## Fix path

1. From `infra/ansible/`: `uv run ansible-playbook playbooks/syslog_server.yml`
2. `uv run ansible-playbook playbooks/csr_logging.yml`
3. Re-test with `debug` or `clear log` + induced event (lab only).
