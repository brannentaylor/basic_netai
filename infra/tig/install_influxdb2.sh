#!/usr/bin/env bash
# Phase A1: install InfluxDB OSS 2.x from InfluxData APT repo (run as root once).

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root once, e.g.: sudo bash $0" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# Earlier attempts may have written ubuntu/<codename> before we fall back to
# debian stable — that leaves a broken entry and makes the *first* apt-update
# fail before this script can fix it. Drop stale Influx lists, then refresh APT.
rm -f /etc/apt/sources.list.d/influxdata.list

apt-get update
apt-get install -y ca-certificates curl gnupg

# Use influxdata-archive.key (current signing subkeys). Do not use
# influxdata-archive_compat.key — it is obsolete per InfluxData key rotation.
install -d -m 0755 /etc/apt/keyrings
KEY=/etc/apt/keyrings/influxdata.gpg
rm -f "$KEY"
curl -fsSL https://repos.influxdata.com/influxdata-archive.key | gpg --batch --dearmor -o "$KEY"
chmod 0644 "$KEY"
rm -f /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg

# shellcheck disable=SC1091
source /etc/os-release
# InfluxData publishes per-codename Ubuntu pockets (e.g. noble, jammy). New or
# non-LTS Ubuntu releases (e.g. questing) may 404 until Influx adds them — use
# the Debian stable channel as a compatible fallback for influxdb2 packages.
LIST=/etc/apt/sources.list.d/influxdata.list
if [[ "${ID}" == "ubuntu" ]]; then
  case "${VERSION_CODENAME}" in
    focal|jammy|noble|mantic|lunar)
      echo "deb [signed-by=${KEY}] https://repos.influxdata.com/ubuntu ${VERSION_CODENAME} stable" >"$LIST"
      ;;
    *)
      echo "Note: using InfluxData debian stable channel (no usable ubuntu/${VERSION_CODENAME} pocket)." >&2
      echo "deb [signed-by=${KEY}] https://repos.influxdata.com/debian stable main" >"$LIST"
      ;;
  esac
else
  echo "deb [signed-by=${KEY}] https://repos.influxdata.com/${ID} ${VERSION_CODENAME} stable" >"$LIST"
fi

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
