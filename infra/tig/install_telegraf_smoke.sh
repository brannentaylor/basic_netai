#!/usr/bin/env bash
# Phase A smoke: install Telegraf and write localhost cpu/mem metrics to InfluxDB 2.
# Reads INFLUX_ORG, INFLUX_BUCKET, INFLUX_TOKEN from infra/tig/.env (never committed).
#
# Run on TIGger from repo root:
#   sudo bash infra/tig/install_telegraf_smoke.sh
#
# Influx DEB standard unit uses BOTH --config and --config-directory for telegraf.d.
# Older script revisions appended duplicate @include lines into telegraf.conf; that causes
# double-loading and startup failure — we strip that block once, then rely on systemd layout.

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/infra/tig/.env"
TOKEN_PATH=/etc/telegraf/influx_token
MAIN_CONF=/etc/telegraf/telegraf.conf
CONF_DIR=/etc/telegraf/telegraf.d
# .conf suffix: --config-directory only loads *.conf on many distro packages (not *.toml).
CONF_FRAGMENT="${CONF_DIR}/99-smoke-local.conf"

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
  echo "Warning: apt-get install exited ${apt_ec}." >&2
  echo "         Continuing — configuring telegraf drop-ins and restarting the service." >&2
fi

systemctl stop telegraf 2>/dev/null || true
systemctl reset-failed telegraf 2>/dev/null || true

# Remove erroneous @include appendix from earlier basic_netai script versions (duplicate load).
if [[ -f "$MAIN_CONF" ]] && grep -q 'basic_netai install_telegraf_smoke' "$MAIN_CONF"; then
  echo "Removing legacy basic_netai @include appendix from ${MAIN_CONF} (duplicate fragments break startup)." >&2
  sed -i '/^# Added by basic_netai install_telegraf_smoke/,$ d' "$MAIN_CONF"
fi
rm -f "${CONF_DIR}/smoke-local.toml"

umask 077
printf '%s' "$INFLUX_TOKEN" >"$TOKEN_PATH"
chmod 0640 "$TOKEN_PATH"
chown root:telegraf "$TOKEN_PATH"

mkdir -p "${CONF_DIR}"
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

# Match distro ExecStart (-config-directory loads ONLY *.conf in telegraf.d on many builds).
TG_TEST=(telegraf --config "$MAIN_CONF" --config-directory "$CONF_DIR")

echo "Running Telegraf foreground test (matches systemd wiring) ..."
set +e
"${TG_TEST[@]}" --test >/tmp/telegraf-smoke-test.log 2>&1
tf_ec=$?
set -e
tail -n 45 /tmp/telegraf-smoke-test.log || true

if [[ "${tf_ec}" -ne 0 ]]; then
  echo "Warning: telegraf --test exited ${tf_ec} (see snippet above)." >&2
  echo "Continuing with systemctl restart; if the service stays down, inspect journalctl next." >&2
  journalctl -u telegraf -n 20 --no-pager 2>/dev/null || true
fi
rm -f /tmp/telegraf-smoke-test.log

systemctl enable telegraf
systemctl restart telegraf
sleep 2
if ! systemctl is-active --quiet telegraf; then
  journalctl -u telegraf -n 60 --no-pager >&2 || true
  exit 1
fi
systemctl --no-pager --full status telegraf || true

echo ""
echo "Grafana Explore Flux (after ~1m):"
echo '  from(bucket: "YOUR_BUCKET") |> range(start: -15m) |> filter(fn: (r) => r._measurement == "cpu") |> limit(n: 5)'
echo "YOUR_BUCKET=${INFLUX_BUCKET}"
