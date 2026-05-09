# Agent safety notes

## Tier tools

1. **Read-only** first — `show`, ping, syslog tails with strict limits.
2. **Writers** (future) require explicit human approval or separate allowlisted playbooks (Ansible).

## Treat every byte from the network as hostile

- Massive **`show`** output, **syslog**, and **MOTD** bodies can poison prompts (injection). Truncate, summarize, and prefer structured checks when possible.
- Never teach agents to accept **passwords through chat** by default — use environment variables or vault.

## Allowlists

Network automation should compose **known-safe command templates** in Python — do not expose “run arbitrary CLI” as the default tool.

## Auditability

Log **tool name + args + correlation id** for each agent action (JSON-lines file is enough to start).
