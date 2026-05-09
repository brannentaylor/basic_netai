# Redaction checklist (public posts)

Before publishing logs, screenshots, or journal entries:

- Remove **passwords**, **SNMP communities**, **API keys**, **SSH private keys**, **internal URLs**.
- Replace customer identifiers if this lab ever moves beyond your own gear.
- Truncate **syslog** / **show tech** excerpts — treat them as untrusted text for readers and models alike.
- Never commit **`.env`** — only `.env.example` with placeholders.
