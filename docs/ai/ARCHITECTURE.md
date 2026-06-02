# Architecture

This repository is organized as a reusable kit plus provider-specific adapters.
`README.md` remains the broad user-facing map; this file is the agent-oriented
architecture guide for changing the repo safely.

## Overview

`ai-agent-kit` ships shared AI development policy and workflow assets to target
projects. Tool-agnostic concepts live in shared folders such as `skills/` and
`project-template/`; Claude Code, Codex CLI, and Antigravity CLI specifics live under
their own `tooling/<tool>` adapters. Install/update/uninstall scripts distribute
managed assets into target projects while preserving project-owned context such
as `docs/ai` and `.mcp.json`.

The healthy architecture shape is a configurator, not a platform. The repository
should stay easy to install, update, uninstall, inspect, and version. Optional
adapters such as GitHub Actions templates, MCP examples, plugin metadata, and
extension scaffolds must not become hidden core dependencies.

## Layered Model

| Layer | Main paths | Responsibility |
|---|---|---|
| Domain | `skills/`, engineering guidance, reusable prompts where applicable | Shared agent knowledge and reusable development behavior. |
| Application | `scripts/install.*`, `scripts/update.*`, `scripts/uninstall.*`, `scripts/validate.*`, `scripts/new-skill.*` | Lifecycle operations that install, refresh, remove, validate, and scaffold kit assets. |
| Infrastructure | `.github/workflows/`, `tooling/*/hooks/`, MCP examples, GitHub Actions templates | CI checks, provider hook runtime, and optional external integrations. |
| Interfaces | `README.md`, `tooling/codex/AGENTS.md`, `tooling/claude/CLAUDE.md`, `tooling/agy/AGY.md`, `.claude-plugin/`, `project-template/` | Human-facing docs, provider-facing route files, plugin metadata, and target project templates. |

## Repository Structure

| Path | Responsibility |
|---|---|
| `skills/` | Reusable tool-agnostic skills. The same skill source is installed for Claude, Codex, and Antigravity. |
| `tooling/claude/` | Claude-specific configuration, agents, commands, hooks, rules, and future output style or statusline assets. |
| `tooling/codex/` | Codex-specific configuration, hooks, skills, profiles, and future context or telemetry assets. |
| `tooling/agy/` | Antigravity-specific configuration, commands, agents, settings fragments, and extension scaffold. |
| `tooling/shared/` | Shared installable assets used across providers, including the opt-in agent audit runtime. |
| `project-template/` | `docs/ai` templates installed into target projects. |
| `scripts/` | Install, update, uninstall, validate, and skill-scaffolding scripts for Windows and POSIX shells. |
| `prompts/` | Copy-paste workflow prompts and GitHub Actions templates. |
| `docs/ai/` | Repository-specific AI context for maintaining this kit itself. |
| `agent-audit/` | Anonymized audit storage policy and fixtures on `master`; generated run data belongs on the future `agent-audit-data` branch. |
| `AGENTS.md`, `CLAUDE.md`, `.agents/`, `.claude/`, `.codex/` | Tracked Claude/Codex dogfood install for maintaining this repository with the kit itself. |
| `examples/filled-project/` | Example filled `docs/ai` content for a fictional target project. |
| `.claude-plugin/` | Claude plugin marketplace metadata for the skills-only distribution path. |

## Dogfood vs source

This repository tracks a Claude/Codex dogfood install at the root so the kit can
be used while maintaining the kit. Those root files are installed outputs, not
the canonical source for provider behavior.

| Dogfood output in this repo | Canonical source |
|---|---|
| `AGENTS.md`, `.codex/config.toml`, `.codex/hooks.json`, `.codex/hooks/` | `tooling/codex/AGENTS.md`, `tooling/codex/config.toml`, platform-specific `tooling/codex/hooks*.json`, `tooling/codex/hooks/` |
| `.agents/skills/` | Shared `skills/` plus Codex-only agent skills under `tooling/codex/skills/` |
| `CLAUDE.md`, `.claude/settings.json`, `.claude/agents/`, `.claude/commands/`, `.claude/hooks/`, `.claude/rules/` | `tooling/claude/CLAUDE.md`, platform-specific `tooling/claude/settings*.json`, and matching `tooling/claude/*/` directories |
| `.claude/skills/` | Shared `skills/` |
| `.ai-agent-kit/audit/` | Shared `tooling/shared/agent-audit/` runtime |
| Future root Antigravity dogfood files | Not tracked today. If that changes, update ADR-004, `.kit-manifest`, validation, and CI in the same scoped issue. Canonical Antigravity source remains `tooling/agy/`. |

Edit the canonical source first, then refresh this repository's dogfood install
with `scripts/update.* -Target "." -Tools codex,claude`. Commit the source
change and the refreshed dogfood output together when both are part of the same
issue.

`scripts/validate.* -Target "."` has a repo-only drift check: when it sees this
source tree and `.kit-manifest`, it compares tracked Claude/Codex dogfood files
against their canonical `tooling/` or `skills/` sources. Platform-specific
outputs such as `.codex/hooks.json` and `.claude/settings.json` may match either
the POSIX or Windows source variant.

## Repository Invariants

- `skills/` is the shared skill source.
- `tooling/` contains tool-specific adapters.
- `project-template/` is copied to target `docs/ai/` during install when the
  target has no existing project context.
- `prompts/` contains reference prompts and optional workflow templates; it is
  not auto-installed by default.
- `agent-audit/` on `master` contains policy and anonymized fixtures only; real
  generated audit run data belongs on the dedicated `agent-audit-data` branch.
- `.mcp.json` is bootstrapped once in target projects and then becomes
  project-owned.
- `.mcp.example.jsonc` remains kit-owned reference documentation.
- `.kit-manifest` tracks kit-managed files in target projects.
- `docs/ai/` in this repository is intentionally tracked project context for
  `ai-agent-kit` itself.
- Root Claude/Codex install artifacts are intentionally tracked here as the
  repository's dogfood configuration.
- Root Antigravity install artifacts are not tracked in this repository.
- Claude local/runtime files such as `.claude/settings.local.json`,
  `.claude/session-log/`, `.claude/worktrees/`, and `CLAUDE.local.md` are not
  tracked.

## Design Principle

Shared concepts must not depend on provider-specific details. Provider adapters
may reference shared policies, but shared policy should avoid Claude-only,
Codex-only, or Antigravity-only assumptions unless explicitly marked.

Install scripts distribute managed assets into target projects. Project-owned
files must not be overwritten by update/install unless they are explicitly
managed kit outputs. In target projects, `docs/ai/` and `.mcp.json` are
project-owned after creation.

## Supported Tool Boundaries

### Claude Code

Claude Code supports skills, commands, agents, hooks, rules, and MCP
configuration. It has the richest runtime guardrail surface in this kit.

### Codex CLI

Codex CLI supports `AGENTS.md`, skills, hooks, `config.toml`, and MCP
configuration. Codex behavior should stay in `tooling/codex/` unless it is
generic shared policy.

### Antigravity CLI

Antigravity CLI supports `AGY.md`, commands, agents, skills/settings, and MCP
settings. The kit wires its hooks through `.agy/settings.json` (a `hooks`
block using the `BeforeTool`/`AfterTool`/`SessionEnd` events with the
`run_shell_command` matcher), including the `pre-bash-guard` safety hook and
the audit-event hook — giving it hook-level parity with Claude and Codex,
backed as always by approval mode, review, and CI validation.

## Architecture Boundaries

### Shared Policy Layer

Includes reusable rules, skills, governance docs, and future `tooling/shared`
assets. This layer can describe principles such as issue-first workflow,
context checkpoints, MCP least privilege, model routing, and subagent ROI.

This layer must not require a specific provider runtime.

### Provider Adapter Layer

Includes `tooling/claude`, `tooling/codex`, and `tooling/agy`. These folders
translate shared policy into provider-native files such as `CLAUDE.md`,
`AGENTS.md`, `AGY.md`, hooks, commands, agent files, settings, and extension
metadata.

Provider adapters may differ when the tools differ. Do not hide those
differences.

### Installation Infrastructure Layer

Includes `scripts/install.*`, `scripts/update.*`, `scripts/uninstall.*`,
`scripts/validate.*`, and `scripts/new-skill.*`.

This layer owns file distribution semantics, manifest tracking, dry-run behavior
where implemented, and validation. Do not change these scripts without a
dedicated GitHub issue and PR.

### Project Template Layer

Includes `project-template/`. These files are copied into target projects as
initial `docs/ai` content. They should stay generic and should not describe this
repository's internal backlog.

### Documentation Layer

Includes `README.md`, `CHANGELOG.md`, and this `docs/ai/` folder.

`README.md` is user-facing product documentation. `docs/ai/` is agent-facing
operational context. Do not copy the full README into `docs/ai`; link concepts
and summarize the rules agents need for safe work.

## Dependency Rules

- `skills/` must remain provider-agnostic.
- `tooling/<tool>` may depend on shared skills and documented shared policy.
- `project-template/` may reference general kit concepts but should avoid
  repo-specific implementation backlog.
- `scripts/` may know about concrete destination paths for providers.
- `docs/ai/` may describe all layers, but should not become a second README.
- Future governance features should start as docs or shared policy, then be
  integrated into provider adapters and scripts only through scoped issues.
- GitHub Actions and release checks belong under `.github/workflows/`.
- Optional adapters must not become core by accident.

## Future Governance Placement

- Context, subagent, MCP, model-routing, and sanitization policies belong in
  `docs/ai` first for this repository.
- If these policies become installable kit assets, create a dedicated issue to
  decide their canonical home, likely `tooling/shared`.
- Provider-specific wiring belongs under the matching `tooling/<tool>` folder.
- Script integration belongs under `scripts/` and must be handled separately
  from policy-writing work.
- A future `doctor` command belongs in the lifecycle script layer, not in
  provider adapters.
- Public-release hygiene belongs in repository documentation, root metadata, and
  release workflows, not in target project templates.

## Key Flows

### Install Flow

1. A user runs `install.ps1` or `install.sh` with a target path and tool list.
2. Shared skills are copied into provider-specific skill locations.
3. Provider adapter files are copied into the target project.
4. `project-template/` files are copied into `docs/ai` only when missing.
5. `.kit-version` and `.kit-manifest` record the installed version and managed files.

### Update Flow

1. A user runs `update.ps1` or `update.sh`.
2. The script reads installed tools from `.kit-version` unless a tool list is supplied.
3. Managed kit files are byte-compared and refreshed if different.
4. `docs/ai` and `.mcp.json` remain project-owned and are not overwritten.
5. Manifest-based pruning removes stale managed assets where supported.

### Agent Work Flow

1. Read the current issue or task.
2. Read only relevant `docs/ai` files.
3. Use deterministic search before broad investigation.
4. Use subagents only when they reduce total context cost.
5. Make final decisions and edits in the main agent session.
6. Verify with relevant scripts before PR.

## Architecture Decisions

See [DECISIONS.md](./DECISIONS.md).

## Provider Parity

For a feature-by-feature comparison of how the kit wires Claude / Codex /
Antigravity (hooks, subagents, MCP, sandbox, permissions, delegation, audit, …),
see [PROVIDER_PARITY.md](./PROVIDER_PARITY.md).
