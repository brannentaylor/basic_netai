"""Thin surfaces callable by autonomous agents (keep side effects obvious)."""

from network_lab.tools.show import run_show_command
from network_lab.tools.syslog_read import read_recent_lab_syslog_lines

__all__: list[str] = ["read_recent_lab_syslog_lines", "run_show_command"]
