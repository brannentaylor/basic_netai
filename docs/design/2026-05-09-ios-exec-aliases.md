# Design: IOS-XE EXEC aliases (`sib`, `sir`, `sis`, `u`) — human review before deploy

**Status:** Proposal — peer review (**implementation artefacts are in-repo; deploy only after sign-off**)  
**Audience:** Humans + Ansible maintainer  
**Lab:** Cisco CSR1000v (inventory group **`csr_lab`**)

## Summary

Automate **`alias exec`** definitions on **all CSRs**, identical on each router, so operators can shorten common privileged **EXEC** **`show`** and **`undebug`** actions during lab troubleshooting.

## Target configuration (canonical)

Applied identically on **csr01**, **csr02**, **csr03**:

```
alias exec sib show ip interface brief
alias exec sir show ip route
alias exec sis show interface status
alias exec u undebug all
```

## Goals

| Goal | How |
| --- | --- |
| **Consistency** across the lab | Group **`csr_lab`**, shared playbook lines (no host_vars divergence). |
| **Reversible, auditable** change | Ansible **`ios_config`**, **`--check --diff`** before apply; design + sign-off gate. |
| **Low blast radius** | EXEC aliases only — no routing, ACL, or control-plane protocol changes. |

## Risks / notes

| Topic | Detail |
| --- | --- |
| **`sis` portability** **`show interface status`** is common on **switch-optimized** IOS images; **CSR1000v** may **not** accept it (router image). After deploy, type **`sis`** on one CSR; if invalid, change the underlying command in the playbook (e.g. **`show ip interface brief`**) and re-apply. |
| **Name collisions** Reserved short names **`sib`**, **`sir`**, **`sis`**, **`u`** could overlap local ad-hoc aliases; review before apply. |
| **Privilege** Aliases run in **EXEC** mode; underlying commands still require the usual **enable** / authorization model. |

## Operational workflow (same pattern as other lab playbooks)

### 1) Human peer review (this doc)

Reviewer checklist:

- [ ] Accept the four shorthand names and backing commands (`u` ↔ **`undebug all`**).
- [ ] Confirm **`sis`** behaviour on CSR (or document an alternate mapping).
- [ ] Agree rollback (below).

### 2) Ansible dry-run (no changes)

From **`infra/ansible/`**:

```bash
export CSR_SSH_USERNAME=cisco
export CSR_SSH_PASSWORD='your-password'

uv run ansible-playbook playbooks/exec_aliases.yml --check --diff
```

### 3) Controlled apply (after sign-off)

```bash
uv run ansible-playbook playbooks/exec_aliases.yml --diff
```

### 4) Verification

**Interactive (quick):** on each CSR, run **`sib`**, **`sir`**, **`sis`**, **`u`** ( **`u`** when no debugs active should still be benign).

**Optional Ansible read-only playbook:**

```bash
uv run ansible-playbook playbooks/verify_exec_aliases.yml
```

### 5) Rollback sketch (manual)

Per device:

```
configure terminal
no alias exec sib
no alias exec sir
no alias exec sis
no alias exec u
end
write memory
```

Or remove only the offending line with **`no alias exec <name>`**.

## Artefacts

| Path | Purpose |
| --- | --- |
| **`infra/ansible/playbooks/exec_aliases.yml`** | Idempotent **`ios_config`** for the four aliases; **`save_when: changed`**. |
| **`infra/ansible/playbooks/verify_exec_aliases.yml`** | **`show running-config \| include ^alias exec`** style snapshot. |
| **`infra/ansible/README.md`** | Dry-run vs apply commands. |

## Sign-off block

| Role | Name | Date | Notes |
| --- | --- | --- | --- |
| Reviewer | ______ | _____ | _____ |
| Operator | ______ | _____ | _____ |
