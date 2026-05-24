# Project Context

This file describes `PetrovC/ai-agent-kit` for AI agents working in this
repository. Keep it concise, factual, and aligned with `README.md`.

## Project Purpose

`ai-agent-kit` is a reusable, versioned AI agent configuration kit for
AI-assisted software development across Claude Code, Codex CLI, and Gemini CLI.
It standardizes work across these tools by shipping shared skills,
provider-specific adapters, optional hooks, commands, MCP examples, workflow
prompts, install/update/uninstall scripts, and `docs/ai` templates for target
projects.

The product soul is deliberately narrow: this repository is a fast, reusable,
multi-agent configurator. It is not an orchestration platform, hosted service,
model proxy, dependency bot, or CI/CD product.

In this repository, `docs/ai/` is official project-owned documentation for
`ai-agent-kit` itself and should be tracked intentionally. This repository also
intentionally dogfoods its own Claude Code and Codex CLI install, so the root
`AGENTS.md`, `CLAUDE.md`, `.agents/`, `.claude/`, `.codex/`, `.mcp.json`,
`.mcp.example.jsonc`, `.kit-version`, and `.kit-manifest` are tracked as
project-local configuration for maintaining the kit. Gemini root install output
and local/runtime Claude files remain excluded.

## Problem Solved

AI coding tools drift when each tool keeps separate instructions, prompts, and
workflow habits. This kit reduces that drift by:

- keeping root instruction files short and focused on routing;
- lazy-loading skills only when relevant;
- keeping project context in `docs/ai`;
- keeping provider-specific behavior under `tooling/<tool>`;
- keeping MCP configuration opt-in;
- using scoped subagents when they reduce total context cost;
- making install, update, validate, and uninstall behavior repeatable.

## Target Users

- Maintainers of this kit.
- Developers installing the kit into their own repositories.
- AI coding agents reading the installed route files, skills, and `docs/ai`
  context.
- Solo developers using multiple AI coding tools.
- Teams that want shared AI agent rules across repositories.
- Projects needing repeatable Claude Code, Codex CLI, and Gemini CLI setup.
- AI-assisted development workflows based on GitHub issues and pull requests.

## Core Principles

- Root instruction files are routers, not encyclopedias.
- Project-specific context lives in `docs/ai`.
- Skills are lazy-loaded and should not be read all at once.
- Provider-specific behavior stays under `tooling/<tool>`.
- Shared policies belong in `docs/ai` today and may later move into
  `tooling/shared` or installable shared assets when an issue defines that work.
- MCPs are opt-in and follow least privilege.
- Subagents are scoped, justified, and useful only when they reduce total
  context cost.
- Deterministic search such as `rg` or `git grep` should come before broad LLM
  investigation for exact lookup tasks.
- No code implementation should start without a GitHub issue.
- No implementation should be delivered without a pull request.
- One concern per issue and one concern per PR.
- Simple, maintainable workflows beat over-engineered automation.
- Optional adapters must stay optional; GitHub Actions templates, MCP examples,
  the Claude plugin metadata, and the Gemini extension scaffold must not become
  required core runtime.
- Human review remains part of the workflow.

## In Scope

- Lifecycle scripts: `install`, `update`, `uninstall`, `validate`, and
  `new-skill` for Bash and PowerShell.
- Shared engineering skills under `skills/`.
- Tool-specific routers, configs, commands, agents, and hooks under
  `tooling/claude`, `tooling/codex`, and `tooling/gemini`.
- Hooks where the provider supports them.
- Project templates under `project-template/`.
- Optional GitHub Actions templates under `prompts/github-actions/`.
- Optional MCP examples.
- Claude plugin marketplace metadata.
- Gemini extension scaffold.
- Documentation, release hygiene, and public onboarding.

## Non-goals

- Replacing human review.
- Hiding the real differences between Claude Code, Codex CLI, and Gemini CLI.
- Enabling every tool, skill, MCP, or workflow by default in every project.
- Forcing one rigid workflow for every repository.
- Using the most expensive model for every task.
- Treating context thresholds or cache windows as hard automatic laws.
- Turning governance into bureaucracy.
- Implementing future governance features without a scoped issue and PR.
- Building a full GitHub agent orchestrator.
- Becoming a CI/CD platform.
- Becoming a dependency update bot.
- Building an IDE plugin.
- Serving as a model proxy.
- Providing a cost tracking platform.
- Claiming to be a security sandbox.
- Shipping a hosted dashboard, backend product, or SaaS.
- Generating application architecture for target projects.

## Main Workflows

1. A maintainer updates the kit source, skills, documentation, or adapters.
2. A user installs the kit into a target project with selected tools.
3. An agent reads the target project's root router file, `docs/ai/`, and only
   the relevant skills for the task.
4. A maintainer validates scripts, skills, routing, and documentation before a
   release.

## Current Priorities

- Keep `docs/ai/` official, accurate, and useful for this repository.
- Keep the tracked Claude/Codex dogfood install portable and aligned with the
  source assets under `tooling/`.
- Improve public-release hygiene with a root `LICENSE`, `SECURITY.md`,
  `CONTRIBUTING.md`, root `VERSION`, release tags, and a release checklist.
- Strengthen validation and lifecycle script coverage without refactoring
  scripts in documentation-only work.
- Add a future `doctor` command that diagnoses target project installation
  health after a dedicated issue exists.
- Keep GitHub Actions, MCP, plugin, and Gemini extension paths as optional
  adapters.

## Current Maturity

The kit already has mature building blocks:

- shared tool-agnostic skills under `skills/`;
- provider adapters under `tooling/claude`, `tooling/codex`, and
  `tooling/gemini`;
- lifecycle hooks for Claude Code and Codex CLI;
- Claude and Gemini commands plus prompt templates;
- subagent definitions for investigation, review, security, architecture, and
  test runs;
- install, update, uninstall, validate, and new-skill scripts;
- `project-template/` files for target `docs/ai` setup.

Current maturity assessment:

- Product vision is strong and clear.
- Scope is mostly respected; GitHub Actions, MCP, plugin, and extension pieces
  remain optional adapters.
- Architecture separation is good, but boundaries between shared skills and
  tool-specific behavior must stay explicit.
- Usability is good for the maintainer and private projects; public onboarding
  can improve.
- Script robustness is better than a first glance suggests, with meaningful
  Bash and PowerShell care already present, but it still needs isolated helper
  tests and parity checks.
- Runtime security is stronger for Claude and Codex because hooks are available;
  Gemini has weaker runtime guard support and relies more on approval mode,
  review, and CI.
- Public release maturity needs work before broad public adoption.
- Evolution potential is excellent, but advanced features should come after
  stabilizing the core.

## Known Risks

- Bash and PowerShell behavior can drift without parity checks.
- Gemini currently lacks an equivalent hook guard system.
- Optional GitHub Actions templates can drift from actual provider behavior.
- MCP examples and mutable GitHub Action tags carry supply-chain risk.
- The kit could become over-engineered if it grows beyond configurator scope.
- Bus factor matters if the project becomes public and widely used.

## Future Direction

Future work should make the kit lighter, safer, and clearer without making it
rigid. The most valuable planned directions are:

- minimal and full install profiles;
- shared context, subagent, MCP, model-routing, and sanitization policies;
- Claude statusline and minimal output style;
- clearer model hints for commands as well as agents;
- Gemini compression guidance and minimal command support;
- Codex context policy and model-routing support;
- validation that root instruction files stay short;
- validation that project-owned files are not overwritten;
- README and CHANGELOG updates when governance assets become installable.

Every future improvement above needs a dedicated GitHub issue with problem,
scope, acceptance criteria, and out-of-scope notes before implementation.
