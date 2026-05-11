# Design: Loopback0, prefix-list / route-map, OSPFv2 redistribution (human review before deploy)

**Status:** Proposal — peer review (**implementation artefacts are in-repo; deploy only after sign-off**)  
**Audience:** Humans + Ansible maintainer  
**Lab:** Cisco CSR1000v, OSPFv2 single area 0 (triangle **`10.0.12/13/23.0/24`** on Gi1/Gi2/Gi3 + **`10.0.0.0/24`** on **Gi4** passive — **`site_routing.yml`**)

## Summary

Automate deployment of **`Loopback0`** on each CSR using addresses aligned with **`router-id`** (**1.1.1.1**, **2.2.2.2**, **3.3.3.3**), then **selectively redistribute** only those prefixes into **OSPF process 1** using a **`prefix-list` + `route-map`**, marking externals as **Type E1** (metric **Type 1**, `metric-type 1`).

## Goals

| Goal | How |
| --- | --- |
| Stable **`router-id` / LOOPBACK parity** | `Loopback0` IP = **`csr_ospf_router_id`** (`/32`). |
| **Least privilege** redistribution | **`redistribute connected … route-map`** so only prefixes matching the **`prefix-list`** enter OSPF as external LSAs — **P2P transit** stays **internal** (**`ip ospf 1 area 0`** on triangle links only). |
| Rich path metric externally | **`metric-type 1`** (**E1**): seed metric grows by **internal cost to ASBR**, better than **E2** for multi-exit comparisons when desired. |

## Risks / non-goals

| Risk | Mitigation |
| --- | --- |
| **Route feedback / loops** Lab has single redistribution hop; topology is bounded. Peer review rejects if redistribution policies expand. |
| **Filtering mistakes** Explicit **`/32` only** permits; deny implicit at route-map end. |
| **Existing `redistribute`** Playbook assumes **none** conflicting; review `show running-config \| sec router ospf`. |

Non-goals: NSSA/STUB redesign, BFD, BFD auth, WAN QoS.

## Per-device target state

| Host | **`Loopback0` IP / mask** | **`router-id`** (unchanged) | Prefix-list semantics |
| --- | --- | --- | --- |
| **csr01** | `1.1.1.1/255.255.255.255` | `1.1.1.1` | Permit `1.1.1.1/32`. |
| **csr02** | `2.2.2.2/255.255.255.255` | `2.2.2.2` | Permit `2.2.2.2/32`. |
| **csr03** | `3.3.3.3/255.255.255.255` | `3.3.3.3` | Permit `3.3.3.3/32`. |

## IOS-XE snippet (conceptual — exact strings in Ansible playbook)

```
interface Loopback0
 description basic_netai LOOPBACK_ROUTER-ID
 ip address <router-id quad> 255.255.255.255
!
ip prefix-list PL-BASICNETAI-LOOPBACK seq 10 permit <router-id>/32
!
route-map RM-BASICNETAI-LOOPBACK-RD permit 10
 match ip address prefix-list PL-BASICNETAI-LOOPBACK
!
router ospf 1
 redistribute connected subnets route-map RM-BASICNETAI-LOOPBACK-RD metric-type 1
```

**Why `route-map` + `metric-type 1` together:** redistribution **filter first** (`match prefix-list`), then **OE1 metric** propagation for richer SPF decisions vs default **E2**.

**Ordering note:** Ansible tasks create **prefix-list**, **route-map**, **Loopback**, then **`redistribute`** so `connected` includes **Loopback0**.

## Why not only `network 1.1.1.1 0.0.0.0 area 0`?

Intra-area **Network LSA** is often simpler operationally — this proposal follows the requested **distribution control** (**prefix-list** + **route-map**) and **explicit E1 semantics** educational goal.

Future ADR may switch to **`network`** for loopbacks and drop redistribution.

## Operational workflow (requested)

### 1) Human peer review (this doc)

Reviewers checklist:

- [ ] Accept **E1** vs **intra-area** tradeoff rationale.
- [ ] Confirm **mgmt / non-lab subnets** excluded (prefix-list narrowly `/32`).
- [ ] Sanity-check **BGP / other IGP absent** (`show running`).
- [ ] Agree rollback (next section).

### 2) Ansible dry-run (no changes)

From `infra/ansible/`:

```bash
export CSR_SSH_USERNAME=cisco
export CSR_SSH_PASSWORD='your-password'

uv run ansible-playbook playbooks/loopback_redistribute.yml --check --diff
```

Interpret warnings; **`--diff`** illustrates intended lines (`ios_config` **may** summarize).

### 3) Controlled production apply

Manual approval gate — reviewer types apply:

```bash
uv run ansible-playbook playbooks/loopback_redistribute.yml --diff
```

### 4) Verification

On **each CSR** (`show-run` abbreviated OK):

```
show ip interface brief Loopback0
show ip protocols | sec ospf   ! confirm redist line present
show ip route | include (/32|OE1|E1).*1\.|2\.|3\.
ping 2.2.2.2 source Loopback0
ping 3.3.3.3 source Loopback0
```

On neighbor CSRs ping **foreign** `/32`s.

Optional:

```
show ip ospf database external | include Metric|Advertising
```

Or execute **`playbooks/verify_loopback_ospf.yml`** (see artefacts table below).

### 5) Rollback sketch (manual)

```
configure terminal
router ospf 1
 no redistribute connected subnets route-map RM-BASICNETAI-LOOPBACK-RD metric-type 1
!
no route-map RM-BASICNETAI-LOOPBACK-RD permit 10
no ip prefix-list PL-BASICNETAI-LOOPBACK
interface Loopback0
 shutdown
end
write memory
```

(Exact `no redistribute` grammar may omit some keywords depending on IOS — **`no redistribute connected`** fallback.)

## Artefacts implementing this proposal

Implemented in-repo; **apply only after reviewer sign-off**:

| Path | Purpose |
| --- | --- |
| **`infra/ansible/playbooks/loopback_redistribute.yml`** | Apply staged config. |
| **`infra/ansible/playbooks/verify_loopback_ospf.yml`** | Read-only `show` snapshot after deploy (`ios_command`). |
| **`infra/ansible/README.md`** subsection | Dry-run vs deploy wording. |

### Optional Ansible verification (instead of SSH copy-paste)

```bash
cd ~/basic_netai/infra/ansible
uv run ansible-playbook playbooks/verify_loopback_ospf.yml
```

## Sign-off block

| Role | Name | Date | Notes |
| --- | --- | --- | --- |
| Reviewer one | ______ | _____ | _____ |
| Operator executing apply | ______ | _____ | _____ |
