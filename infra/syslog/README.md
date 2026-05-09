# Syslog receiver fragment (rsyslog)

This directory holds **versioned** rsyslog configuration you can install on the Ubuntu control VM.

- **Do not** expose UDP/514 outside the lab segment.
- Prefer **Ansible** (`infra/ansible/playbooks/syslog_server.yml`) so installs stay reproducible.
