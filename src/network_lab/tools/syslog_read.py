"""Read-only syslog access for troubleshooting (strict path allowlist)."""

from __future__ import annotations

from pathlib import Path

# Default aggregate file created by infra/syslog + Ansible playbook.
DEFAULT_AGGREGATE_LOG = Path("/var/log/network-lab/all.log")
_ALLOWED_ROOT = Path("/var/log/network-lab")


def read_recent_lab_syslog_lines(*, lines: int = 200, log_path: Path | None = None) -> str:
    """Return the last ``lines`` lines from an allowed lab syslog file.

    Args:
        lines: Line budget (keep small before feeding an LLM).
        log_path: Optional override; must still sit under ``/var/log/network-lab``.

    Returns:
        Newline-delimited text (possibly empty).

    Raises:
        ValueError: Line budget out of range or path escapes allowlist.
        FileNotFoundError: Path missing.
    """

    if lines < 1 or lines > 10_000:
        raise ValueError("lines must be between 1 and 10000 inclusive.")

    target = Path(log_path) if log_path is not None else DEFAULT_AGGREGATE_LOG
    resolved = target.resolve()
    root = _ALLOWED_ROOT.resolve()
    try:
        resolved.relative_to(root)
    except ValueError as exc:
        raise ValueError("log_path must live under /var/log/network-lab.") from exc

    if not resolved.is_file():
        raise FileNotFoundError(f"Syslog file not found: {resolved}")

    text = resolved.read_text(encoding="utf-8", errors="replace").splitlines()
    tail = text[-lines:]
    return "\n".join(tail)
