"""Safety checks for syslog tail helper."""

from __future__ import annotations

from pathlib import Path

import pytest

from network_lab.tools import syslog_read as syslog_read_module
from network_lab.tools.syslog_read import read_recent_lab_syslog_lines


def test_read_recent_lines_returns_tail(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(syslog_read_module, "_ALLOWED_ROOT", tmp_path)

    log_file = tmp_path / "all.log"
    lines = [f"line-{index}" for index in range(5)]
    log_file.write_text("\n".join(lines), encoding="utf-8")

    out = read_recent_lab_syslog_lines(lines=2, log_path=log_file)
    assert out == "line-3\nline-4"


def test_rejects_path_outside_allowlist(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(syslog_read_module, "_ALLOWED_ROOT", tmp_path)
    evil_dir = tmp_path.parent / f"outside-{tmp_path.name}"
    evil_dir.mkdir(exist_ok=True)
    bad_file = evil_dir / "secret.log"
    bad_file.write_text("nope", encoding="utf-8")
    with pytest.raises(ValueError, match="log_path must live"):
        read_recent_lab_syslog_lines(log_path=bad_file)
