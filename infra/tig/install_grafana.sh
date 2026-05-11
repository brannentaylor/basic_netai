#!/usr/bin/env bash
# Phase A1: install Grafana OSS from official APT repo (run as root once).

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root once, e.g.: sudo bash $0" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gpg

install -d -m 0755 /etc/apt/keyrings
GPG=/etc/apt/keyrings/grafana.gpg
curl -fsSL https://apt.grafana.com/gpg.key | gpg --dearmor -o "$GPG"
chmod 0644 "$GPG"

echo "deb [signed-by=${GPG}] https://apt.grafana.com stable main" >/etc/apt/sources.list.d/grafana.list

apt-get update
apt-get install -y grafana

systemctl enable --now grafana-server

echo "Grafana installed. Verify:"
echo "  systemctl status grafana-server"
echo "  ss -tlnp | grep ':3000' || true"
echo "Browse (from lab CIDR or SSH tunnel): http://<TIGger>:3000/ — first login sets admin password."
echo "Add InfluxDB datasource (Flux) and import CSR SNMP dashboard — docs/monitoring/tig/README.md and infra/tig/grafana/README.md."
