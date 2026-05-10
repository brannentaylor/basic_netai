#!/usr/bin/env bash
# Phase A smoke: install Telegraf and write localhost cpu/mem metrics to InfluxDB 2.
# Reads INFLUX_ORG, INFLUX_BUCKET, INFLUX_TOKEN from infra/tig/.env (never committed).
#
# Run on TIGger from repo root: sudo bash infra/tig/install_telegraf_smoke.sh
#
# The telegraf DEB may try to start the service during post-install before drop-ins
# exist; we tolerate that failure, lay down config + @include, then start cleanly.

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/infra/tig/.env"
TOKEN_PATH=/etc/telegraf/influx_token
MAIN_CONF=/etc/telegraf/telegraf.conf
CONF_FRAGMENT=/etc/telegraf/telegraf.d/smoke-local.toml

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
set +e
apt-get install -y telegraf
apt_ec=$?
set -e
if [[ "${apt_ec}" -ne 0 ]]; then
  echo "Warning: apt-get install exited ${apt_ec} (telegraf package post-install often starts systemd before config exists)." >&2
  echo "         Continuing — we will configure drop-ins and restart the service." >&2
fi

systemctl stop telegraf 2>/dev/null || true
systemctl reset-failed telegraf 2>/dev/null || true

umask 077
printf '%s' "$INFLUX_TOKEN" >"$TOKEN_PATH"
chmod 0640 "$TOKEN_PATH"
chown root:telegraf "$TOKEN_PATH"

mkdir -p /etc/telegraf/telegraf.d

# Official packages sometimes ship a main-only config without @include for telegraf.d,
# leaving drop-ins invisible — Telegraf exits with “no outputs” or similar.
if [[ -f "$MAIN_CONF" ]] && ! grep -qE '^@include.*/telegraf\.d' "$MAIN_CONF"; then
  {
    printf '\n# Added by basic_netai install_telegraf_smoke.sh — load fragment directory.\n'
    printf '%s\n' '@include "/etc/telegraf/telegraf.d/*.toml"'
    printf '%s\n' '@include "/etc/telegraf/telegraf.d/*.conf"'
  } >>"$MAIN_CONF"
fi

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
EOF
chmod 0644 "$CONF_FRAGMENT"

echo "Running one-shot Telegraf validation ..."
set +e
telegraf --config "$MAIN_CONF" --test >/tmp/telegraf-smoke-test.log 2>&1
tf_ec=$?
set -e
tail -n 40 /tmp/telegraf-smoke-test.log
if [[ "${tf_ec}" -ne 0 ]]; then
  echo "telegraf --test exited ${tf_ec}. Check influx org/bucket/token and configs above." >&2
fi
rm -f /tmp/telegraf-smoke-test.log

systemctl enable telegraf
systemctl start telegraf
sleep 1
systemctl --no-pager --full status telegraf || true

echo ""
echo "If active: Grafana Explore Flux (after ~1m):"
echo '  from(bucket: "YOUR_BUCKET") |> range(start: -15m) |> filter(fn: (r) => r._measurement == "cpu") |> limit(n: 5)'
echo "Replace YOUR_BUCKET with: ${INFLUX_BUCKET}"
echo "Otherwise: journalctl -u telegraf -n 50 --no-pager"
