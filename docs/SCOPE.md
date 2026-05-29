# Project Scope

`ai-agent-kit` is a reusable, versioned multi-agent configurator. Its job is to
install, update, uninstall, validate, and document a consistent AI-agent setup
for Claude Code, Codex CLI, and Antigravity CLI.

## Goal

Make AI-assisted software development more repeatable across supported tools by
sharing skills once, keeping root routers short, preserving project-owned
context, and providing optional adapters where they help.

## Guarantees

- Shared skills have one source under `skills/`.
- Root router files stay short and delegate to skills and `docs/ai/`.
- Target project context belongs in `docs/ai/`.
- Install and update distinguish kit-managed files from project-owned files.
- This repository may track its own Claude/Codex dogfood install as
  project-local configuration.
- Optional adapters remain optional.
- Human review, issue scope, and PR review stay part of the workflow.

## Non-goals

- Full orchestration platform.
- Hosted SaaS.
- Dependency update bot.
- Model proxy.
- Cost dashboard.
- IDE plugin.
- Security sandbox.
- Project architecture generator.
- Replacement for human PR review.

## Component Maturity

| Maturity | Components | Notes |
|---|---|---|
| Core/stable | Lifecycle scripts, shared skills, route files, project templates, Claude/Codex hooks | Continue strengthening validation and parity checks before adding large features. |
| Optional adapters | MCP examples, GitHub Actions templates, Claude plugin marketplace metadata, Antigravity extension scaffold | Keep opt-in and document risk clearly. |
| Future/experimental | Doctor command, init wizard, skill evals, skill SemVer, Antigravity wrapper | Require dedicated issues and PRs before implementation. |
