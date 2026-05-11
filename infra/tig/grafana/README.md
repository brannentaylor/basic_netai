# Grafana dashboards (TIGger, Phase A3)

JSON lives under **`dashboards/`** in this directory. Import from the Grafana UI (no secrets in these files).

## `csr-snmp-overview.json`

**CSR SNMP (lab)** — Flux queries on measurement **`csr_snmp`** (**`sysUpTime`** field, **`sysName`** / **`agent_host`** tags from Telegraf).

### Import (Grafana UI)

1. Sign in to Grafana (**`http://<TIGger>:3000`** or your SSH tunnel URL).
2. Left menu: **Dashboards** → **Import** (or **Connections** → **Dashboards** → **Import**, depending on Grafana version).
3. **Upload dashboard JSON file** → choose **`infra/tig/grafana/dashboards/csr-snmp-overview.json`** from your clone (or paste the file contents into the text box).
4. **Import** wizard:
   - **InfluxDB (Flux)** — pick your existing InfluxDB 2 datasource (same one you use in **Explore**).
   - Confirm **Unique identifier (uid)** or allow overwrite if re-importing.
5. Open the dashboard. If **No data**, set the **Bucket** variable (top) to your Influx bucket (default **`lab-bucket`**) and widen the time range (top right).

### Prerequisites

- InfluxDB datasource configured with **Query language: Flux**, org/token/bucket consistent with **`infra/tig/.env`** and Telegraf **`outputs.influxdb_v2`**.
- Telegraf writing **`csr_snmp`** (Phase A2 **`install_telegraf_snmp_csr.sh`**).

### Editing the bucket name

Dashboard variable **Bucket** (`influx_bucket`) defaults to **`lab-bucket`**. To change: dashboard **Settings** (gear) → **Variables** → **Bucket** → set **Constant** value, or edit JSON before import.
