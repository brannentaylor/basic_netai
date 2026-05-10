#!/usr/bin/env bash
# Phase A0: ufw skeleton — allow SSH; restrict Grafana (3000) and Influx (8086)
# to TIG_LAB_ALLOW_CIDR from dotenv.example / `.env`.
#
# Copy infra/tig/dotenv.example to .env, set TIG_LAB_ALLOW_CIDR, then either:
#   sudo bash -c 'set -a; source /path/to/.env; set +a; bash /path/to/install_ufw_tig.sh'
# or export TIG_LAB_ALLOW_CIDR before running.

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root once, e.g.: sudo bash $0" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/infra/tig/.env"

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a
  # shellcheck disable=SC1091
  source "$ENV_FILE"
  set +a
fi

: "${TIG_LAB_ALLOW_CIDR:?Set TIG_LAB_ALLOW_CIDR (see infra/tig/dotenv.example)}"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ufw

# TODO(agent/operator): confirm SSH port if non-default (e.g. match `ss -tlnp`).
ufw allow OpenSSH

ufw allow from "${TIG_LAB_ALLOW_CIDR}" to any port 3000 proto tcp comment 'Grafana lab'
ufw allow from "${TIG_LAB_ALLOW_CIDR}" to any port 8086 proto tcp comment 'InfluxDB2 HTTP lab'

echo "Review rules before enabling (default deny incoming):"
ufw show added || true
echo "Enable with: ufw enable   # interactive confirm"
echo "Then: ufw status verbose"
