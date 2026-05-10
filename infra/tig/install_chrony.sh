#!/usr/bin/env bash
# Phase A0: install and enable chrony for stable time on TIGger (run as root once).
#
# Preconditions: Ubuntu/Debian-style host; network reach NTP servers or edit
# /etc/chrony/sources.d/ if you use local strata.

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root once, e.g.: sudo bash $0" >&2
  exit 1
fi

# TODO(agent/operator): pin NTP pools or on-prem servers per site policy.
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y chrony

systemctl enable --now chrony

echo "chrony enabled. Verify (examples):"
echo "  chronyc tracking"
echo "  timedatectl status"
