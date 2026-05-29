# Security Policy

`ai-agent-kit` is a reusable configuration kit for AI coding tools. It ships
files that target projects install into their own repositories — including
hooks that intercept agent behavior. This document explains how to report a
vulnerability, what is in scope, and what guarantees the kit does (and does
not) provide.

## Reporting a vulnerability

Please report security issues **privately** before opening a public issue.

- Preferred channel: open a [GitHub Security Advisory](https://github.com/PetrovC/ai-agent-kit/security/advisories/new).
- Fallback: email the maintainer (see the `author` field in
  [`.claude-plugin/plugin.json`](./.claude-plugin/plugin.json)).

What to include:

- A clear description of the issue and the kit version (`.kit-version`).
- Reproduction steps (commands, repo layout, agent invocation).
- The expected vs. observed behavior.
- The realistic impact (what an attacker could do).

What to expect:

- Acknowledgement within 7 days.
- A coordinated disclosure timeline agreed before any public mention.
- Credit in the changelog and advisory once the fix ships, unless you ask
  to remain anonymous.

Please do **not** open a public issue, PR, or discussion that describes an
unpatched vulnerability.

## Scope

In scope:

- Lifecycle scripts: `scripts/install.{sh,ps1}`, `scripts/update.{sh,ps1}`,
  `scripts/uninstall.{sh,ps1}`, `scripts/validate.{sh,ps1}`,
  `scripts/new-skill.{sh,ps1}`.
- Hooks shipped under `tooling/claude/hooks/` and `tooling/codex/hooks/`.
- Provider configuration files installed by the kit
  (`tooling/<tool>/settings*.json`, `tooling/codex/config.toml`,
  `tooling/agy/settings.json`, `.claude-plugin/*`).
- Optional GitHub Actions templates under `prompts/github-actions/`.
- MCP examples shipped as reference (not enabled by default).

Out of scope (report upstream instead):

- Vulnerabilities in Claude Code, Codex CLI, or Antigravity CLI themselves.
- Vulnerabilities in third-party MCP servers referenced as examples — report
  to that server's maintainer.
- Vulnerabilities in target projects' application code.
- Vulnerabilities introduced by a target project's local edits to installed
  files (`.mcp.json`, `docs/ai/`, project-owned settings).

## Hook posture (ADR-007)

The kit's hooks are **best-effort guardrails, not a security sandbox**.

- They block common destructive commands (`git push --force*`, `git reset
  --hard`, recursive `rm -rf` against unsafe targets, SQL `DROP` without
  approval markers, etc.).
- They run inside the same process tree as the agent and use the same
  filesystem and network permissions.
- They depend on `bash` or `pwsh` being available and on the agent honoring
  the hook protocol.
- They can be bypassed by an agent that ignores hooks, by a user that
  disables hooks, or by a command that the denylist does not yet cover.

In short: hooks reduce accident risk; they do not provide isolation or
defense against a hostile agent. Run agents in least-privilege environments
and review their work.

## MCP risk model

`.mcp.json` is bootstrapped empty and is **project-owned after creation**
(ADR-010). MCP servers are external dependencies with their own permissions
and update cadence. See [`docs/ai/MCP_POLICY.md`](./docs/ai/MCP_POLICY.md)
for the kit's MCP guidance:

- No MCP enabled by default.
- Prefer read-only and least-privilege scopes.
- Pin upstream versions; do not depend on mutable tags.
- Treat every MCP server as untrusted code with the access you granted it.

## Supported versions

The kit is currently pre-1.0. Only the latest tag receives security fixes.
Once a 1.x line is cut, the previous minor will receive critical fixes for
90 days.

## Hardening recommendations

For target projects:

- Pin the kit version (`.kit-version` + a tag) instead of tracking `master`.
- Review `tooling/<tool>/settings*.json` before adopting; cut what you do not
  need.
- Treat `.mcp.json` as security-sensitive — review every server you add.
- Disable hooks you do not understand rather than running them blindly.
- Keep `.env`, credentials, and secrets out of the agent's working directory.
- See [`docs/ai/CONTEXT_SANITIZATION.md`](./docs/ai/CONTEXT_SANITIZATION.md)
  before pasting external logs or documents.

## References

- [ADR-007 — Hooks are guardrails, not a sandbox](./docs/ai/DECISIONS.md)
- [Threat model](./docs/ai/THREAT_MODEL.md)
- [MCP policy](./docs/ai/MCP_POLICY.md)
- [Context sanitization](./docs/ai/CONTEXT_SANITIZATION.md)
- [Workflow](./docs/ai/WORKFLOW.md)
