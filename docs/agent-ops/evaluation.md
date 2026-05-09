# Evaluation ideas (lightweight)

- **Fixture tests** without LLMs: given inventory YAML, ensure parsing + tool wiring behave (already in `pytest`).
- **Scenario harness (future):** freeze a lab snapshot description + user goal → expect certain **final states** (`show ip ospf neighbor` counts, syslog markers).
- **Golden transcripts:** optional sanitized chat exports under `docs/agent-ops/examples/` strictly for teaching — not CI.

Start small: add one integration test marked `@pytest.mark.integration` once SSH to the lab is stable.
