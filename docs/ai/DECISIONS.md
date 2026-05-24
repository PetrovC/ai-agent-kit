# Technical Decisions

This file records accepted product and architecture decisions for AI agents
working on `ai-agent-kit`. Keep entries compact. Add new decisions when a future
issue changes direction.

## ADR-001: One shared skill source

- Context: Claude Code, Codex CLI, and Gemini CLI need overlapping engineering
  guidance.
- Decision: Core skills live under `skills/` and are deployed to the supported
  tools instead of being maintained three times.
- Consequences: Skills must stay tool-agnostic unless a provider-specific copy
  is explicitly justified.

## ADR-002: Short root router files

- Context: Loading full project policy into every root instruction file wastes
  context.
- Decision: `CLAUDE.md`, `AGENTS.md`, and `GEMINI.md` stay short and route
  agents to `docs/ai/` and relevant skills.
- Consequences: Detailed policy belongs in skills, templates, or `docs/ai`, not
  in root routers.

## ADR-003: Project context lives in docs/ai

- Context: Agents need project-specific context that survives across sessions
  and tools.
- Decision: Target projects use `docs/ai/` for project context.
- Consequences: Install and update must preserve existing target `docs/ai/`
  content unless a file is explicitly kit-managed.

## ADR-004: docs/ai is tracked in this repository

- Context: This repository also needs agent-facing context for maintaining the
  kit itself.
- Decision: `docs/ai/` is official project-owned documentation for
  `ai-agent-kit` and should be tracked intentionally here.
- Consequences: CI must allow root `docs/ai/` while continuing to reject other
  root install outputs.

## ADR-005: Provider behavior stays under tooling/<tool>

- Context: Claude, Codex, and Gemini have different config formats, hooks,
  command systems, and runtime capabilities.
- Decision: Provider-specific behavior belongs under `tooling/claude/`,
  `tooling/codex/`, or `tooling/gemini/`.
- Consequences: Shared policy may be referenced by adapters, but shared skills
  and docs should not depend on one provider's private format.

## ADR-006: GitHub Actions templates are optional

- Context: The kit ships optional workflow templates and prompt assets.
- Decision: GitHub Actions templates are reference assets, not core install
  outputs and not auto-installed by default.
- Consequences: They can mature as optional adapters, but must not turn the kit
  into a CI/CD platform.

## ADR-007: Hooks are guardrails, not a sandbox

- Context: Claude and Codex hooks can intercept or guide behavior, but they are
  not a hardened runtime boundary.
- Decision: Hooks provide practical guardrails and workflow feedback, not a
  security sandbox.
- Consequences: Security documentation and review remain necessary, and hooks
  must not be marketed as complete isolation.

## ADR-008: Gemini has weaker runtime guard support

- Context: Gemini support exists, but this kit does not currently provide an
  equivalent hook guard system for Gemini.
- Decision: Gemini safety relies more on approval mode, review, CI, and clear
  router guidance.
- Consequences: Documentation must be honest about the weaker runtime guard
  surface.

## ADR-009: MCPs are opt-in

- Context: MCP servers can add power, context load, and external risk.
- Decision: MCP servers are not enabled by default.
- Consequences: MCP examples should follow least privilege and task relevance.

## ADR-010: .mcp.json is project-owned after bootstrap

- Context: Target projects may customize their active MCP configuration.
- Decision: `.mcp.json` may be bootstrapped once, then belongs to the target
  project.
- Consequences: Update must not overwrite project-owned `.mcp.json`; the kit can
  maintain `.mcp.example.jsonc` as reference documentation.

## ADR-011: Update refreshes only kit-managed files

- Context: Users need repeatable updates without losing local project context.
- Decision: Update refreshes files tracked as kit-managed and preserves
  project-owned files.
- Consequences: `.kit-manifest` semantics and preservation tests are core
  lifecycle behavior.

## ADR-012: No implementation without issue and PR

- Context: The kit changes scripts, hooks, and provider behavior that can affect
  user repositories.
- Decision: Implementation work must be tied to a GitHub issue and delivered
  through a PR.
- Consequences: Documentation may record planned work, but feature work waits
  for scoped issue and review.

## ADR-013: Subagents must reduce total context cost

- Context: Subagents can save context or waste it by duplicating broad reading.
- Decision: Use subagents only when they prevent broad main-context reads,
  summarize noisy output, or provide focused expert review.
- Consequences: A vague or duplicative subagent report is not an optimization.

## ADR-014: No weak models for decision-bearing reports

- Context: Low-tier models can be useful for mechanical work but risky for
  high-judgment analysis.
- Decision: Architecture, security, investigation, and review reports need an
  appropriately strong model and narrow scope.
- Consequences: Weak models are not bad generally; they are inappropriate for
  decision-bearing reports.

## ADR-015: Context thresholds are heuristics

- Context: Context percentage alone does not measure reasoning quality.
- Decision: 40%, 60%, and 80% context thresholds are governance checkpoints,
  not automatic laws.
- Consequences: 40% means pause and evaluate, 60% means compaction is strongly
  recommended, and 80% means summarize and restart.

## ADR-016: Cache freshness is a signal

- Context: Short prompt/cache windows can affect efficiency.
- Decision: A 5-minute idle window is a workflow hygiene signal, not a forced
  session boundary.
- Consequences: Continue the same task with compaction if context is heavy;
  start fresh for unrelated work.

## ADR-017: Deterministic search first

- Context: Exact lookup tasks do not require broad LLM investigation.
- Decision: Use `rg`, `git grep`, targeted file search, or file listing before
  spawning `codebase-investigator` for exact symbols, usages, keys, endpoints,
  or filenames.
- Consequences: Subagents should handle interpretation, noisy summaries, or
  second opinions after cheap exact lookup.

## ADR-018: Advanced orchestration stays outside the core

- Context: The project could grow into an agent platform if optional ideas are
  promoted too quickly.
- Decision: Advanced orchestration, hosted dashboards, dependency bots, model
  proxies, cost platforms, and IDE plugins stay outside the core kit unless a
  future issue explicitly promotes a narrow adapter.
- Consequences: The core remains a maintainable multi-agent configurator.

