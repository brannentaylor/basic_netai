# Device baseline snapshots (local only)

`snapshot_configs.yml` writes **timestamped folders** here (for example **`20260509T153045Z/`**).

Each run contains **`MANIFEST.txt`**, **`README_SNAPSHOT.txt`**, one folder per **`csr_lab`** router, and per-command **`*.txt`** files suitable for **`diff`** between snapshots.

Because **`show running-config`** may contain **secrets**, paths under this directory are **gitignored**. Keep tarballs offline or encrypt if you archive them elsewhere.
