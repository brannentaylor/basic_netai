# ADR 0001 — Monorepo with uv-managed Python

## Status

Accepted

## Context

We need predictable Python environments for agents and humans, plus Ansible living beside the code for a small lab.

## Decision

- Keep **one Git repo** (`basic_netai`) for Python, Ansible, syslog fragments, and docs.
- Manage dependencies with **uv**; commit **`uv.lock`**.

## Consequences

- Simple navigation for learners; larger repo if automation explodes (revisit in a future ADR).
- CI can call `uv sync` + `uv run pytest` deterministically.
