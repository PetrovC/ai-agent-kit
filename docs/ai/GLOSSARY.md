# Glossary

| Term | Definition |
|---|---|
| `ai-agent-kit` | Reusable, versioned AI agent configuration kit for Claude Code, Codex CLI, and Antigravity CLI. |
| Agent | AI coding assistant operating in this repository or in a target project. |
| Adapter | Tool-specific configuration that maps shared kit concepts into one provider's files and runtime behavior. |
| Command | Provider-facing shortcut or prompt asset that triggers a repeatable workflow. |
| Context checkpoint | Pause to decide whether to compact, compress, summarize, or start a fresh session. |
| Context cost | Token and attention cost of reading files, logs, reports, and prior conversation state. |
| Deterministic search | Exact local search using `rg`, `git grep`, targeted file lookup, or direct file listing. |
| Doctor command | Planned diagnostic command that would inspect a target project's kit installation health. |
| Full install profile | Planned install mode that would copy the complete selected-tool kit. |
| Hook | Provider-supported script or callback used as a guardrail or workflow aid. Hooks are not a sandbox. |
| Kit-managed file | File copied by install/update and tracked in `.kit-manifest`. |
| Lifecycle script | Script that installs, updates, uninstalls, validates, or scaffolds kit assets. |
| Manifest | `.kit-manifest`, the target project record of files managed by the kit. |
| MCP | Model Context Protocol. MCPs attach external tools or data sources and should be opt-in and least-privilege. |
| Minimal install profile | Planned install mode that would copy only the broadly useful core assets. |
| Optional template | Reference asset, such as a GitHub Actions template, that users may copy intentionally but is not installed by default. |
| Parity check | Test that compares equivalent behavior across Bash/PowerShell or Claude/Codex/Antigravity routes. |
| Project-owned file | File owned by the target project and preserved by update/uninstall, such as `docs/ai/` or `.mcp.json`. |
| Provider adapter | Tool-specific configuration under `tooling/claude`, `tooling/codex`, or `tooling/agy`. |
| Public release hygiene | Metadata and process needed for broad public use, including `LICENSE`, `SECURITY.md`, `CONTRIBUTING.md`, root `VERSION`, release tags, and checklist. |
| Release tag | Git tag and GitHub Release marker that lets users pin a known kit version. |
| Router | Short root instruction file such as `CLAUDE.md`, `AGENTS.md`, or `AGY.md` that points agents to relevant docs and skills. |
| Rule | Provider-specific or shared instruction that constrains agent behavior. |
| Sanitized context | Precise reduced context that preserves exact errors and evidence while removing duplication and noise. |
| Skill | Focused Markdown instruction file under `skills/` or a provider-specific installed skill location. |
| Subagent | Specialized agent used for scoped investigation, review, security, architecture, or test summarization. |
| Supply-chain risk | Risk from external templates, MCP servers, actions, mutable tags, downloaded scripts, or unpinned third-party assets. |
| Target project | Repository where users install `ai-agent-kit`. |
| Tool-agnostic skill | Skill under `skills/` that should not depend on one provider's config format. |
| VERSION file | Planned root file intended to become the single source of truth for kit version metadata. |

