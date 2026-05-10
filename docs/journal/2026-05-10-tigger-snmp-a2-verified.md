# Journal — SNMP Phase A2 lab verification (CSR + TIGger)

## Context

TIG stack on **TIGger** (`10.0.0.24`); **csr_lab** CSRs reachable on management IPs in **`infra/ansible/inventory/hosts.yml`**.

## Goal

Stable **SNMPv2c read-only** from TIGger to each CSR (**sysName** / Telegraf **`csr_snmp`**) without CSR1000v **`access-list could not be allocated / incompatible type`** failures seen when binding **`snmp-server … RO`** to **named extended** ACLs.

## Answer / outcome

- **Playbook `csr_snmp.yml`:** prelude wipes **`snmp-server`**, clears numbered ACL **`csr_snmp_standard_acl_num`** (default **87**), best-effort removes legacy **named** lists; **`access-list 87 permit host`** *TIGger*; **`snmp-server community … RO 87`** when missing from **`show running-config`**.
- **`verify_csr_snmp.yml`:** asserts **`snmp-server community`** + **`show ip access-list 87`** (or configured number).
- **TIGger proof:** **`apt install snmp`**, **`snmpget`** to **`1.3.6.1.2.1.1.5.0`** returns **`STRING: \"…\"`** (MIB-II **sysName** — routing + ACL OK).
- **`install_telegraf_snmp_csr.sh`** remains the CSR Telegraf wiring from **`hosts.yml`**.

## Problems + resolution

| Symptom | Fix |
| --- | --- |
| Cisco **`could not be allocated`** on **csr02/csr03** | Move bind to **numbered standard** ACL (**87**) instead of **named extended** ACL reference. |
| **`group_vars`** “undefined” ACL vars | Filename must stay **`csr_lab.yml`** (matches inventory group **`csr_lab`**). |
| **`snmpget: command not found`** | **`sudo apt-get install snmp`** on TIGger. |
| **`bash: foo: No such file or directory`** with **`<mgmt_ip>`** | **`<`** is redirection — use **literal IPs** from **`hosts.yml`**. |

## Repo changes

Documented across **`docs/AGENT_ONBOARDING.md`**, **`docs/design/2026-05-10-tigger-TIG-snmp-phased.md`**, **`docs/monitoring/tig/README.md`**, **`docs/monitoring/tig/snmp-ios-xe.md`**, **`infra/ansible/README.md`**, playbooks/templates under **`infra/ansible/`**. See **`git log`** on **`main`** for the integrating commit(s).
