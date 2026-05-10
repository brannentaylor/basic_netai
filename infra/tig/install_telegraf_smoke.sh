#!/usr/bin/env bash
# Phase A smoke: Telegraf localhost cpu/mem → InfluxDB 2 (runs on TIGger).
#
# Telegraf stays installed across runs; apt only ensures the package exists.
#
# Notes for Telegraf v1.38+:
# - outputs.influxdb_v2 no longer honors token_file → use token = "${INFLUX_TOKEN}"
# - strict env var handling → INFLUX_TOKEN must be injected (systemd EnvironmentFile).
# - Stock unit appends $TELEGRAF_OPTS; replace ExecStart in a drop-in if unset opts break startup.

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/infra/tig/.env"
MAIN_CONF=/etc/telegraf/telegraf.conf
CONF_DIR=/etc/telegraf/telegraf.d
CONF_FRAGMENT="${CONF_DIR}/99-smoke-local.conf"
TOKEN_ENV=/etc/telegraf/influx_smoke.env
UNIT_DROPIN=/etc/systemd/system/telegraf.service.d/basic-netai-smoke.conf
# Populated after `apt-get install telegraf`
TE_BIN=""

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
TE_BIN="$(command -v telegraf || true)"
if [[ -z "${TE_BIN}" ]]; then
  echo "'telegraf' binary not found on PATH after install." >&2
  exit 1
fi

systemctl stop telegraf 2>/dev/null || true
systemctl reset-failed telegraf 2>/dev/null || true

restore_stock_main_conf() {
  [[ -f "$MAIN_CONF" ]] || return 0
  # Parse-only check of the main config (drops directory loaded separately later).
  if telegraf --config "$MAIN_CONF" --test >/dev/null 2>&1; then
    return 0
  fi
  local backup="${MAIN_CONF}.bak.$(date +%s)"
  echo "Backing up unreadable ${MAIN_CONF} → ${backup} and restoring packaged default …" >&2
  cp -a "$MAIN_CONF" "$backup" || true

  local gz=/usr/share/doc/telegraf/examples/telegraf.conf.gz
  if [[ -f "$gz" ]]; then
    zcat "$gz" >"$MAIN_CONF"
    echo "Restored ${MAIN_CONF} from ${gz}." >&2
    return 0
  fi

  local td deb
  td="$(mktemp -d)"
  if (
    cd "$td" && apt-get download -qq telegraf
  ); then
    deb="$(echo "${td}/"telegraf_*.deb)"
    mkdir -p "${td}/x"
    dpkg-deb -x "$deb" "${td}/x"
    cp "${td}/x/etc/telegraf/telegraf.conf" "$MAIN_CONF"
    echo "Restored ${MAIN_CONF} from ${deb##*/} (no doc example .gz)." >&2
    rm -rf "$td"
    return 0
  fi
  rm -rf "$td"
  echo "Automatic restore failed — try: sudo apt-get install --reinstall telegraf" >&2
  return 1
}

if [[ -f "$MAIN_CONF" ]] && grep -q 'basic_netai install_telegraf_smoke' "$MAIN_CONF"; then
  echo "Removing legacy basic_netai @include appendix from ${MAIN_CONF}." >&2
  sed -i '/^# Added by basic_netai install_telegraf_smoke/,$ d' "$MAIN_CONF"
fi

if ! restore_stock_main_conf; then
  echo "Could not repair ${MAIN_CONF}; fix or reinstall telegraf, then re-run this script." >&2
  exit 1
fi

rm -f "${CONF_DIR}/smoke-local.toml" /etc/telegraf/influx_token

umask 077
{
  printf 'INFLUX_TOKEN=%s\n' "${INFLUX_TOKEN}"
} >"${TOKEN_ENV}.new"
mv "${TOKEN_ENV}.new" "${TOKEN_ENV}"
chown root:root "${TOKEN_ENV}"
chmod 0640 "${TOKEN_ENV}"

mkdir -p /etc/systemd/system/telegraf.service.d
# Stock unit uses `... $TELEGRAF_OPTS` at end of ExecStart. When TELEGRAF_OPTS is unset,
# systemd can still pass an empty argv token; Telegraf then exits 1. Clear + replace ExecStart.
cat >"${UNIT_DROPIN}" <<UNIT
[Service]
EnvironmentFile=/etc/telegraf/influx_smoke.env
ExecStart=
ExecStart=${TE_BIN} -config "${MAIN_CONF}" -config-directory "${CONF_DIR}"
UNIT
chmod 0644 "${UNIT_DROPIN}"

umask 022
mkdir -p "${CONF_DIR}"
cat >"${CONF_FRAGMENT}" <<EOF
# Repo: basic_netai — Telegraf smoke (localhost only). Delete when SNMP config lands.
[[outputs.influxdb_v2]]
  urls = ["http://127.0.0.1:8086"]
  organization = "${INFLUX_ORG}"
  bucket = "${INFLUX_BUCKET}"
  token = "\${INFLUX_TOKEN}"
  timeout = "5s"

[[inputs.cpu]]
  percpu = true
  totalcpu = true

[[inputs.mem]]
EOF
chmod 0644 "${CONF_FRAGMENT}"

systemctl daemon-reload

echo "Telegraf foreground test (as user 'telegraf', matching the service) …"
set +e
if command -v runuser >/dev/null 2>&1; then
  runuser -u telegraf -- env "INFLUX_TOKEN=${INFLUX_TOKEN}" \
    "${TE_BIN}" --config "${MAIN_CONF}" --config-directory "${CONF_DIR}" \
    --test >/tmp/telegraf-smoke-test.log 2>&1
else
  sudo -u telegraf env "INFLUX_TOKEN=${INFLUX_TOKEN}" \
    "${TE_BIN}" --config "${MAIN_CONF}" --config-directory "${CONF_DIR}" \
    --test >/tmp/telegraf-smoke-test.log 2>&1
fi
tf_ec=$?
set -e
tail -n 50 /tmp/telegraf-smoke-test.log || true
rm -f /tmp/telegraf-smoke-test.log

if [[ "${tf_ec}" -ne 0 ]]; then
  echo "telegraf --test exited ${tf_ec}; not starting systemd unit until resolved." >&2
  journalctl -u telegraf -n 30 --no-pager 2>/dev/null || true
  exit "${tf_ec}"
fi

systemctl enable telegraf
systemctl reset-failed telegraf 2>/dev/null || true
systemctl restart telegraf
sleep 2
if ! systemctl is-active --quiet telegraf; then
  journalctl -u telegraf -n 60 --no-pager >&2 || true
  exit 1
fi

systemctl --no-pager --full status telegraf || true

echo ""
echo "Grafana Explore Flux (after ~60s scrape interval):"
echo '  from(bucket: "YOUR_BUCKET") |> range(start: -15m) |> filter(fn: (r) => r._measurement == "cpu") |> limit(n: 5)'
echo "YOUR_BUCKET=${INFLUX_BUCKET}"
