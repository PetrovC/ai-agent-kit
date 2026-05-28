# Agent Audit Repository Area

This folder is the documented home for anonymized agent audit data.

Real generated audit run data belongs on the dedicated `agent-audit-data`
branch. The files committed on `master` are policy notes and anonymized
fixtures only.

## Layout

```text
agent-audit/
  policy/
  indexes/
  runs/YYYY/MM/project-hash/run-id/
```

The storage rules are defined in
[AGENT_AUDIT_STORAGE.md](../docs/ai/AGENT_AUDIT_STORAGE.md), and the payload
schemas are defined in
[AGENT_AUDIT_SCHEMA.md](../docs/ai/AGENT_AUDIT_SCHEMA.md).
Governance scoring and recommendation rules are defined in
[AGENT_AUDIT_GOVERNANCE.md](../docs/ai/AGENT_AUDIT_GOVERNANCE.md).

## Branch Rule

- `master`: schemas, docs, policy, and fixtures.
- `agent-audit-data`: generated anonymized audit runs and generated indexes.

Do not commit real generated run data to `master`.
