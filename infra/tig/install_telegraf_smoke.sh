#!/usr/bin/env bash
# Phase A smoke: install Telegraf and write localhost cpu/mem/disk metrics to InfluxDB 2.
# Reads INFLUX_ORG, INFLUX_BUCKET, INFLUX_TOKEN from infra/tig/.env (never committed).
#
# Run on TIGger from repo root: sudo bash infra/tig/install_telegraf_smoke.sh

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/infra/tig/.env"
TOKEN_PATH=/etc/telegraf/influx_token
CONF_FRAGMENT=/etc/telegraf/telegraf.d/smoke-local.conf

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE — copy infra/tig/dotenv.example and fill INFLUX_* ." >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

: "${INFLUX_ORG:?Set INFLUX_ORG in $ENV_FILE}"
: "${INFLUX_BUCKET:?Set INFLUX_BUCKET in $ENV_FILE}"
: "${INFLUX_TOKEN:?Set INFLUX_TOKEN in $ENV_FILE}"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y telegraf

umask 077
printf '%s' "$INFLUX_TOKEN" >"$TOKEN_PATH"
chmod 0640 "$TOKEN_PATH"
chown root:telegraf "$TOKEN_PATH"

mkdir -p /etc/telegraf/telegraf.d
umask 022
cat >"$CONF_FRAGMENT" <<EOF
# Repo: basic_netai — Telegraf smoke (localhost only). Remove when SNMP inputs land.
[[outputs.influxdb_v2]]
  urls = ["http://127.0.0.1:8086"]
  organization = "${INFLUX_ORG}"
  bucket = "${INFLUX_BUCKET}"
  token_file = "${TOKEN_PATH}"
  timeout = "5s"

[[inputs.cpu]]
  percpu = true
  totalcpu = true

[[inputs.mem]]

[[inputs.disk]]
  ignore_fs = ["tmpfs", "devtmpfs", "squashfs", "overlay"]
EOF
chmod 0644 "$CONF_FRAGMENT"

systemctl enable --now telegraf

echo "Telegraf smoke enabled. Check:"
echo "  systemctl status telegraf"
echo "  journalctl -u telegraf -n 30 --no-pager"
echo "Grafana Explore (Flux), after ~1 minute, use your bucket name in from(...):"
echo '  from(bucket: "YOUR_BUCKET") |> range(start: -15m) |> filter(fn: (r) => r._measurement == "cpu") |> limit(n: 5)'
echo "Replace YOUR_BUCKET with: ${INFLUX_BUCKET}"
