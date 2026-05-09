# Device baseline snapshots (local only)

`snapshot_configs.yml` writes **timestamped folders** here (for example **`20260509T183657Z/`**).

Each run contains:

| File / path | Purpose |
| --- | --- |
| **`manifest.json`** | Machine-readable catalogue: **`snapshot_format_version`**, **`snapshot_id_utc`**, host list, **expected numbered `*.txt` filenames**, pointers to supplementary per-host files. |
| **`MANIFEST.txt`** | Human-oriented diff hints and **`diff -u`** examples. |
| **`<csrNN>/telemetry.json`** | Structured telemetry (same IOS captures as **`*.txt`**), ideal for **`jq`/Python tooling and LLM ingestion. |
| **`<csrNN>/<NN>_*.txt`** | Verbatim **`show`** output with minimal headers (**`diff`**-friendly baseline). |
| **`<csrNN>/00_inventory_meta.txt`** | Ansible inventory finger-post for that subdirectory. |

Because **`show running-config`** may contain **secrets**, baseline payload under this directory is **`gitignored`** except this **`README.md`**. Encrypt or segregate archived tarballs appropriately.

### `telemetry.json` schema (`capture_format_version` **1**)

Top-level keys:

| Key | Meaning |
| --- | --- |
| **`capture_format_version`** | Increment when fields change (**`1`** today). |
| **`snapshot_id_utc`** | Shared folder timestamp (matches **`manifest.json`**, **`MANIFEST.txt`**). |
| **`inventory_hostname`**, **`ansible_host`** | Ansible names from the playbook run. |
| **`captures`** | Ordered list describing each **`*.txt`** IOS capture. |

Each element of **`captures`**:

| Key | Meaning |
| --- | --- |
| **`artifact`** | Matching numbered filename (example **`82_show_ip_ospf_neighbor_detail.txt`**). |
| **`command`** | IOS command string (**`show …`**, may include `\|` pipelines). |
| **`ok`** | **`true`** if **`ios_command` succeeded (**`failed` false**) on that iteration. |
| **`msg`** | Ansible / module diagnostics when **`ok`** is false. |
| **`stdout`** | Flattened text body (newline joined). |
| **`stdout_lines`** | Same payload as JSON array-of-strings (**usually one element per IOS line)**. |

### `jq` quick recipes

Assume **`SNAP=artifacts/baselines/<id>`**:

```bash
# First device only — summarize capture success counts
jq '.captures | map(.ok) | group_by(.) | map({ok: .[0], count: length})' \
  "${SNAP}/csr01/telemetry.json"

# Iterate each host telemetry file — OSPF neighbor detail payloads that succeeded
for f in "${SNAP}"/csr*/telemetry.json; do
  echo "=== $(basename "$(dirname "${f}")") ==="
  jq '.captures[] | select(.artifact=="82_show_ip_ospf_neighbor_detail.txt") | {artifact, ok, stdout}' "${f}"
done

# Running-config payloads (heavy string — preview first line count)
jq '.captures[] | select(.artifact=="30_running-config.txt") | {ok, lines: (.stdout_lines|length)}' \
  "${SNAP}/csr01/telemetry.json"
```
