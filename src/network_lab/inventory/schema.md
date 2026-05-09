# Inventory schema

Top-level YAML object with a ``devices`` list. Each row:

| Field | Required | Meaning |
| --- | --- | --- |
| ``hostname`` | yes | Matches Ansible inventory and docs. |
| ``management_ipv4`` | yes | Reachable CSR management address (SSH). |
| ``platform`` | yes | Declared automation platform (expect ``cisco_iosxe``). |
| ``environment`` | no | Defaults to ``lab``. Tools may refuse non-lab hosts later. |

Copy ``inventory.example.yaml`` to ``inventory.yaml`` for private addressing;
keep the copy out of Git (see ``.gitignore`` if you add that filename).
