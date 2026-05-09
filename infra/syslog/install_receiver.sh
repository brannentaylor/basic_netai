#!/usr/bin/env bash
# Install centralized rsyslog receiver (runs as root once).
#
# Prefer this script on Ubuntu with sudo-rs if `ansible-playbook --ask-become-pass`
# times out feeding the password interactively.

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root once, e.g.: sudo bash $0" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONF_SRC="${REPO_ROOT}/infra/syslog/rsyslog.d/basic_netai-remote.conf"

if [[ ! -f "$CONF_SRC" ]]; then
  echo "Missing config fragment: ${CONF_SRC}" >&2
  exit 1
fi

# Debian/Ubuntu rsyslogd runs as user `syslog` — dir must be writable or omfile suspends.
install -d -o syslog -g adm -m 0775 /var/log/network-lab
# Recover from older installs where rsyslog could not write (partial root-owned file).
[[ -f /var/log/network-lab/all.log ]] && chown syslog:adm /var/log/network-lab/all.log || true
install -o root -g root -m 0644 "$CONF_SRC" /etc/rsyslog.d/99-basic-netai.conf
systemctl enable --now rsyslog
systemctl restart rsyslog

echo "Installed rsyslog drop-in. Verify:"
echo "  ss -ulnp | grep ':514'"
echo "  ls -la /etc/rsyslog.d/99-basic-netai.conf /var/log/network-lab"
