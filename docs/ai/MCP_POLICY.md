# MCP Policy

MCPs are dependencies, not background magic. Loading every MCP by default
increases risk, noise, and accidental coupling.

## Default Position

- No MCP should be enabled by default unless needed.
- Enable only task-relevant MCPs.
- Prefer read-only access.
- Avoid production write access.
- Filter tools when supported.
- Inspect active tools and context before risky tasks.
- MCP usage must remain scoped to the current GitHub issue.

## Least Privilege

Never give broad filesystem, production database, or privileged SaaS access
casually. Start with the smallest useful permission set:

- read-only before write;
- local or sandbox before production;
- narrow path before broad filesystem;
- specific database/schema before whole server;
- specific API scope before admin scope.

## Workflow Rules

- Do not use MCPs to bypass repository workflow rules.
- Do not implement without a GitHub issue just because an MCP makes access easy.
- Do not push directly to `main` or `master`.
- Do not use MCP output as final truth without evidence when the task is
  decision-bearing.
- Document any MCP used for a PR in the PR summary or final response.

## Provider Notes

- Claude Code uses project `.mcp.json` for MCP configuration.
- Codex CLI uses `[mcp_servers.<name>]` tables in `.codex/config.toml`.
- Antigravity CLI uses `mcpServers` in `.agy/settings.json`.

`.mcp.json` is initialized empty and then project-owned. Do not overwrite it in
updates.

## Supply-chain Notes

MCP examples are optional adapter documentation. Treat every MCP server as an
external dependency with its own update cadence, permissions, and operational
risk. Do not promote an MCP example into default install behavior without a
dedicated issue, least-privilege review, and clear acceptance criteria.

When documenting MCP setup, prefer pinned or reviewable configuration examples
where possible and warn when an example depends on mutable external behavior.

## Risk Checks

Before enabling or using an MCP, ask:

- Does the current issue require this external data or tool?
- Is read-only enough?
- Could this expose secrets or production data?
- Could deterministic local search answer the question instead?
- Will this MCP increase context noise more than it helps?

If the risk is unclear, do not enable the MCP until the issue scope is clearer.
