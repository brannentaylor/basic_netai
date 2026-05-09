# 2026-05-09 — Ansible playbook hardening + syslog hygiene + practitioner docs

## Context

Continuing the **`basic_netai`** lab (`basic_netai`): CSR1000v OSPF under Ansible, centralized syslog on Ubuntu (**`10.0.0.21`**, routers **`csr_lab`**), baseline snapshots for diff/forensics.

## Goals (session)

| Track | Desired outcome |
| --- | --- |
| **Baselines** | Hybrid **`artifacts/baselines/**`**: keep **`*.txt`** for **`diff`**, add **`telemetry.json`** + **`manifest.json`** for scripts/agents. |
| **Playbook reliability** | Fix **`snapshot_configs.yml`** Ansible loop/name/register edge cases (**`loop_var`** / **`snapshot_line`**). |
| **Practitioners** | Single instruction manual bridging CLI-first mindset to repo **`infra/ansible`** layout. |
| **Syslog honesty** | Stop duplicate **local Ubuntu** chatter in **`network-lab/all.log`** (**UDP-bound ruleset**). |
| **Runbooks** | grep/tail patterns + reinstall pointer when **`all.log`** is polluted or remote syslog “missing”. |

## Outcomes

| Area | Deliverable |
| --- | --- |
| **Snapshots** | **[`infra/ansible/playbooks/snapshot_configs.yml`](file:///home/brannen/basic_netai/infra/ansible/playbooks/snapshot_configs.yml)** + **[`vars/baseline_snapshot_commands.yml`](file:///home/brannen/basic_netai/infra/ansible/playbooks/vars/baseline_snapshot_commands.yml)** **`telemetry.json` per host**, **`manifest.json`** per snapshot. |
| **Docs / discoverability** | **[`docs/instruction_manual_ansible_lab.md`](file:///home/brannen/basic_netai/docs/instruction_manual_ansible_lab.md)**; cross-links **`README.md`** / **`docs/README.md`**; **`infra/ansible/artifacts/baselines/README.md`** (**JSON schema**, **`jq` examples**). |
| **Rsyslog** | **[`infra/syslog/rsyslog.d/basic_netai-remote.conf`](file:///home/brannen/basic_netai/infra/syslog/rsyslog.d/basic_netai-remote.conf)** **`ruleset` + **`input`** `ruleset=`** routing **only **`imudp/514`**** into **`all.log`**. |
| **Operational** | **`docs/monitoring/syslog.md`**, **`docs/runbooks/no_syslog_from_router.md`** tightened (**grep** patterns, reinstall note). |

## Repo changes / commits (recent `main`; see `git log`)

Representative hashes from this strand (squash narratives not implied):

| SHA | Topic |
| --- | --- |
| **`8bb4d68`** | Snapshot playbook: rename loop tasks (**`item`** undefined). |
| **`17010ff`** | Snapshot gathers use **`artifact_row.snapshot_line`** (custom **`loop_var`**, not **`item`**). |
| **`2a0e2f7`** | Hybrid baseline JSON artefacts + **`vars`** roster file. |
| **`a19a0ee`** | **`instruction_manual_ansible_lab.md`** + indexes. |
| **`4d5da62`** | Rsyslog UDP-only ruleset (omit local **`*.*`** fan-out into **`all.log`**). |

## Problems + resolutions (short)

| Symptom | Resolution |
| --- | --- |
| **`ansible-playbook`** template **`item` undefined** | Static task **`name`** + explicit **`loop_var`**. |
| **`dict` missing **`item`** in register iteration | Iterate **`snapshot_gather.results`** keyed by custom **`snapshot_line`** from **`loop_var`**. |
| **`stdout`** odd shapes | Persist **`flatten` + **`join`** of **`stdout_lines`**. |
| **`all.log` full of **`systemd`/Ubuntu** noise | **`*.*`** in default ruleset duplicated OS logs → dedicated **`basicNetaiRemoteUdp`** ruleset. |
| **Syslog on router vs not on collector** during **Iface admin down** | Path **`router → UDP/514`** lost when **`logging host`** unroutable (lab: align management vs transit). **`tcpdump`** + **`ping`** toward collector confirms. |

## Share hook

> basic_netai: hybrid baseline snapshots (**`telemetry.json`** + **`manifest.json`**), Ansible instruction manual for CLI engineers, and rsyslog **UDP-only ruleset** so **`network-lab/all.log`** mirrors CSR noise only.

## Follow-ups

- Optional ADR: **baseline **`capture_format_version`** evolution** (**JSON schema** pinning).
- Re-run **`install_receiver.sh`** (**or Ansible **`syslog_server.yml`****) on every Ubuntu collector **after **`git pull`**** when infra/syslog configs change — document in team runbook (**done in monitoring doc**).

