# 2026-05-09 — Repository bootstrap

## Context

Greenfield lab for AI-assisted operations against three CSR1000v routers plus an Ubuntu control host.

## Goal

Create the `basic_netai` monorepo: Python (`uv`) inventory + SSH helpers, Ansible for Gi1/OSPF + syslog, and public documentation paths.

## Outcome

Initial tree landed with `network_lab` package, `infra/ansible` playbooks, rsyslog fragment, and monitoring docs.

## Repo changes

- `af03393` — initial scaffold (Python, Ansible, syslog, docs).
- `c5916fd` — optional `logging source-interface` (Gi1 transit vs management footgun).
- `e7077cb` — journal entry links the SHAs above.

## Problems + resolution

- **GitHub SSH push blocked in automation sandboxes** — developers run `git push` from their workstation with keys.
- **CSR SSH algorithms** — OpenSSH 10 may need legacy KEX / `ssh-rsa` host keys (document in your client config).

## Share hook

> Bootstrapped a public `basic_netai` lab repo: uv + Ansible + rsyslog for CSR agent experiments — see docs/journal/2026-05-09-bootstrap.md
