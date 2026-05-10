#!/usr/bin/env bash
# Phase A1: install InfluxDB OSS 2.x from InfluxData APT repo (run as root once).

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root once, e.g.: sudo bash $0" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gnupg

KEY=/etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg
curl -fsSL https://repos.influxdata.com/influxdata-archive_compat.key | gpg --dearmor -o "$KEY"
chmod 0644 "$KEY"

# shellcheck disable=SC1091
source /etc/os-release
# e.g. ubuntu/noble, debian/bookworm — matches InfluxData repo layout.
echo "deb [signed-by=${KEY}] https://repos.influxdata.com/${ID} ${VERSION_CODENAME} stable" >/etc/apt/sources.list.d/influxdata.list

apt-get update
apt-get install -y influxdb2

systemctl enable --now influxdb

echo "InfluxDB 2 installed. Verify:"
echo "  systemctl status influxdb"
echo "  ss -tlnp | grep 8086 || true"
echo ""
echo "Next (first-time only), as a user with shell access on TIGger:"
echo "  influx setup"
echo "Save the admin token into infra/tig/.env as INFLUX_TOKEN (never commit .env). See docs/monitoring/tig/README.md Phase A1."
