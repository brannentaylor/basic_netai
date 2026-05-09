# Replication checklist

1. **Provision** three CSR1000v routers and an Ubuntu 24.04+ control VM on the same /24 (example `10.0.0.0/24`).
2. **SSH client fix (OpenSSH 8+):** CSRs may advertise legacy KEX/host keys — mirror the working `Host *` stanza from the project journal or add per-host `KexAlgorithms` / `HostKeyAlgorithms`.
3. **Clone** `git@github.com:brannentaylor/basic_netai.git`.
4. **Install uv** (<https://docs.astral.sh/uv/>), then `uv sync --all-groups`.
5. Copy `src/network_lab/inventory/inventory.example.yaml` → `inventory.yaml` (gitignored) with your management IPs.
6. Export `CSR_SSH_USERNAME` / `CSR_SSH_PASSWORD`, set `LAB_INVENTORY_PATH` if you use a non-default file.
7. `uv run pytest` — mocked tests should pass offline.
8. **Ansible:** follow [`infra/ansible/README.md`](../infra/ansible/README.md) — install collections, edit **`lab_syslog_collector_ipv4`**, apply **`syslog_server.yml`** (or **`sudo bash infra/syslog/install_receiver.sh`** from repo root — same fragment), then routing + CSR **`csr_logging`** playbooks.
9. **Syslog sanity:** **`/var/log/network-lab/all.log`** must receive **UDP/514 CSR traffic only.** After **`git pull`**, reinstall the **`rsyslog`** drop-in and **`sudo systemctl restart rsyslog`** if **`all.log` still duplicates Ubuntu **`systemd`** lines — see **`docs/monitoring/syslog.md`**.

If something fails, add a **`docs/journal/`** note with symptom → fix so the next learner gets a breadcrumb trail.
