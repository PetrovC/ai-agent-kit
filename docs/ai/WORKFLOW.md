# Workflow

This repository follows an issue-first, PR-first workflow. Documentation can be
prepared directly when requested, but implementation work needs a GitHub issue
and a dedicated branch/PR.

## Issue-first Workflow

Every implementation must start from a GitHub issue. If no issue exists:

- create one if explicitly asked and GitHub access is available; or
- ask the user to create or link one before implementation.

The issue must define:

- problem;
- scope;
- acceptance criteria;
- out-of-scope items;
- verification expectations.

One concern belongs in one issue. Do not group unrelated implementation work.

## PR-first Delivery

- Never push directly to `main` or `master`.
- Create a dedicated branch for the issue.
- Keep one concern per PR.
- Run relevant validation before final response or PR.
- Document risks and assumptions.
- Do not open a PR unless explicitly asked.

## Agent Workflow

1. Audit before editing.
2. Load only relevant context.
3. Prefer deterministic search before broad investigation.
4. Use subagents only when justified by context cost or specialized review.
5. Do not mix documentation and implementation unless the issue explicitly says
   so.
6. Keep final edits in the main agent session.
7. Verify with commands from [COMMANDS.md](./COMMANDS.md).

## Documentation-only Work

Documentation-only work may update `docs/ai`, README, or CHANGELOG when the
task requests documentation. It must not silently include code, hooks, scripts,
provider adapter changes, or feature implementation.

For this docs completion task:

- do not modify install, update, or uninstall scripts;
- do not create feature code;
- do not create future governance assets outside `docs/ai`;
- do not create GitHub issues unless explicitly asked;
- do not open a PR unless explicitly asked.

In this repository, `docs/ai/` is official project-owned context and may be
tracked. The repository also intentionally tracks its own Claude/Codex dogfood
install so agents can use the kit while maintaining the kit:

- `AGENTS.md`
- `CLAUDE.md`
- `.agents/`
- `.claude/`
- `.codex/`
- `.mcp.json`
- `.mcp.example.jsonc`
- `.kit-version`
- `.kit-manifest`

Do not track Gemini root install output in this repository unless a future issue
explicitly expands the dogfood scope. Do not track local/runtime files such as
`.claude/settings.local.json`, `.claude/session-log/`, `.claude/worktrees/`, or
`CLAUDE.local.md`.

## Public-release Hygiene

Public-release hygiene is documentation and metadata work that prepares the kit
for external users. It includes a root `LICENSE`, `SECURITY.md`,
`CONTRIBUTING.md`, root `VERSION`, release tags, and a release checklist.

Add these through scoped issues and PRs. Do not mix public-release hygiene with
script refactors, hook rewrites, new adapters, or roadmap feature
implementation.

## When Future Work Is Discovered

Document the work as planned and recommend a scoped GitHub issue. A good issue
title starts with the concern, such as:

- `feat(scripts): add minimal and full install profiles`
- `feat(claude): add context statusline`
- `docs(shared): add subagent delegation policy`

Do not implement the future work in the same documentation task.
