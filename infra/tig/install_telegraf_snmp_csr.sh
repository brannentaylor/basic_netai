#!/usr/bin/env bash
# Phase A2 — Telegraf snmp input for csr_lab management IPs from Ansible inventory YAML.
#
# Requires: Phase A1-smoke (Telegraf installed + systemd env for Influx). Router side:
# Ansible playbooks/csr_snmp.yml with CSR_SNMP_RO_COMMUNITY exported (same lab string as SNMP_RO_COMMUNITY here).

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/infra/tig/.env"
INV="${REPO_ROOT}/infra/ansible/inventory/hosts.yml"
FRAG=/etc/telegraf/telegraf.d/96-snmp-csr.conf
SNMP_ENV=/etc/telegraf/snmp_lab.env
SNMP_SYSTEMD_DROPIN=/etc/systemd/system/telegraf.service.d/snmp-lab-env.conf

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE — copy infra/tig/dotenv.example and add SNMP_RO_COMMUNITY." >&2
  exit 1
fi
if [[ ! -f "$INV" ]]; then
  echo "Missing inventory $INV" >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

: "${SNMP_RO_COMMUNITY:?Set SNMP_RO_COMMUNITY (lab RO community, match CSR_SNMP_RO_COMMUNITY on Ansible) in $ENV_FILE}"

if ! python3 -c 'import yaml' 2>/dev/null; then
  echo 'Installing python3-yaml for inventory parsing …'
  export DEBIAN_FRONTEND=noninteractive
  apt-get install -y python3-yaml
fi

TE_BIN="$(command -v telegraf || true)"
if [[ -z "${TE_BIN}" ]]; then
  echo 'telegraf not found — run infra/tig/install_telegraf_smoke.sh first.' >&2
  exit 1
fi

umask 077
tmp="${SNMP_ENV}.new.$$"
printf 'SNMP_RO_COMMUNITY=%s\n' "${SNMP_RO_COMMUNITY}" >"${tmp}"
mv "${tmp}" "${SNMP_ENV}"
chown root:root "${SNMP_ENV}"
chmod 0640 "${SNMP_ENV}"

mkdir -p /etc/systemd/system/telegraf.service.d
cat >"${SNMP_SYSTEMD_DROPIN}" <<'DROP'
[Service]
EnvironmentFile=/etc/telegraf/snmp_lab.env
DROP
chmod 0644 "${SNMP_SYSTEMD_DROPIN}"

python3 "${REPO_ROOT}/infra/tig/render_telegraf_snmp_fragment.py" \
  --inventory "${INV}" \
  --interval "${TELEGRAF_CSR_SNMP_INTERVAL:-60s}" \
  --out "${FRAG}.new.$$"
mv -f "${FRAG}.new.$$" "${FRAG}"
chmod 0644 "${FRAG}"
chown root:root "${FRAG}"

systemctl daemon-reload

MAIN_CONF=/etc/telegraf/telegraf.conf
CONF_DIR=/etc/telegraf/telegraf.d

echo "Telegraf snmp config test (as user telegraf) …"
set +e
if command -v runuser >/dev/null 2>&1; then
  runuser -u telegraf -- env \
    "INFLUX_TOKEN=${INFLUX_TOKEN:?Set INFLUX_TOKEN in infra/tig/.env}" \
    "SNMP_RO_COMMUNITY=${SNMP_RO_COMMUNITY}" \
    "${TE_BIN}" --config "${MAIN_CONF}" --config-directory "${CONF_DIR}" \
    --test >/tmp/telegraf-snmp-test.log 2>&1
else
  sudo -u telegraf env \
    "INFLUX_TOKEN=${INFLUX_TOKEN}" \
    "SNMP_RO_COMMUNITY=${SNMP_RO_COMMUNITY}" \
    "${TE_BIN}" --config "${MAIN_CONF}" --config-directory "${CONF_DIR}" \
    --test \
    >/tmp/telegraf-snmp-test.log 2>&1
fi
tf_ec=$?
set -e
tail -n 80 /tmp/telegraf-snmp-test.log || true
rm -f /tmp/telegraf-snmp-test.log

if [[ "${tf_ec}" -ne 0 ]]; then
  echo "telegraf --test exited ${tf_ec}; fix SNMP reachability or community before restart." >&2
  exit "${tf_ec}"
fi

systemctl reset-failed telegraf 2>/dev/null || true
systemctl restart telegraf
sleep 2
if ! systemctl is-active --quiet telegraf; then
  journalctl -u telegraf -n 60 --no-pager >&2 || true
  exit 1
fi

echo "Wrote ${FRAG} and ${SNMP_ENV}; Telegraf is active."
echo "Grafana Explore (Flux), after ~1m:"
echo '  from(bucket: "YOUR_BUCKET") |> range(start: -15m) |> filter(fn: (r) => r._measurement == "csr_snmp") |> limit(n: 10)'
