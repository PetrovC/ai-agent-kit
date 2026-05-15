# ai-agent-kit

A reusable, versioned AI agent configuration kit for Claude Code, Codex CLI, and Gemini CLI.

## Philosophy

- One skill is written once and deployed to all tools.
- Root instruction files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`) are short routers, not encyclopedias.
- Project context lives in `docs/ai/` inside each project — not in this kit.
- Subagents handle noisy, exploratory, or parallel work to protect the main context window.

---

## Official resources

The tools this kit targets, and their official documentation:

| Tool | Source | Docs / Reference |
|---|---|---|
| **Claude Code** (Anthropic) | [github.com/anthropics/claude-code](https://github.com/anthropics/claude-code) | All Anthropic repos: [github.com/orgs/anthropics/repositories](https://github.com/orgs/anthropics/repositories) |
| **Codex CLI** (OpenAI) | [github.com/openai/codex](https://github.com/openai/codex) | GitHub Action: [github.com/openai/codex-action](https://github.com/openai/codex-action) |
| **Gemini CLI** (Google) | [github.com/google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli) | Docs: [google-gemini.github.io/gemini-cli/docs](https://google-gemini.github.io/gemini-cli/docs) |
| **Gemini GitHub Action** | [github.com/google-github-actions/run-gemini-cli](https://github.com/google-github-actions/run-gemini-cli) | — |

---

## Structure

```
ai-agent-kit/
├── skills/               <- Tool-agnostic rules per stack/language/concern
├── tooling/              <- Tool-specific wrappers (Codex / Claude / Gemini)
│   ├── codex/skills/     <- Codex subagent skills (SKILL.md, installed into .agents/skills/)
│   ├── claude/agents/    <- Claude subagent definitions (.md)
│   ├── claude/commands/  <- Claude slash commands (.md, installed into .claude/commands/)
│   ├── claude/hooks/     <- Lifecycle hook scripts (format, guard, notify, summarize)
│   ├── claude/rules/     <- Path-scoped rules (commits, tests, migrations, env)
│   └── gemini/agents/    <- Gemini subagent definitions (.md)
├── project-template/     <- docs/ai/ templates to fill per project
├── prompts/              <- Reference prompt templates (canonical source for slash commands)
│   └── github-actions/   <- Copy-paste GitHub Actions workflow files
└── scripts/              <- Install / update / uninstall / validate scripts
```

**Key design principle:** `skills/` is completely tool-agnostic. The same `skills/dotnet/SKILL.md` is installed into `.agents/skills/` (Codex), `.claude/skills/` (Claude Code), and `.gemini/skills/` (Gemini CLI) by the install script. Tool-specific behaviour (hooks, config syntax, agent format) lives exclusively in `tooling/`.

---

## Quick start (5 minutes)

```powershell
# Windows
.\scripts\install.ps1 -Target "C:\path\to\your-project" -Tools codex,claude

# Linux / macOS
./scripts/install.sh --target /path/to/your-project --tools codex,claude
```

Then fill in `docs/ai/PROJECT.md` and `docs/ai/COMMANDS.md` in your project.

---

## Full kit (30 minutes)

1. Run the install script with all tools.
2. Fill every file in `docs/ai/` of the target project (each file starts with a STOP notice).
3. Run `validate.sh` / `validate.ps1` against the target — confirms templates were filled.
4. Customize skills for your project's stack.
5. Write your first ticket using a prompt from `prompts/` (see "Prompts" below).

---

## How each feature maps to each tool

Understanding what each component does and which tools use it:

### Skills

Skills are the core of the kit. Each skill is a Markdown file with actionable patterns for a specific language or concern (e.g., `skills/dotnet/SKILL.md`). They are loaded **on demand**, not all at once.

| Tool | How skills load |
|---|---|
| **Claude Code** | Skills with `paths:` frontmatter are **auto-loaded** when you open a matching file (e.g., opening `*.cs` triggers the `dotnet` skill). Cross-cutting skills are invoked via the routing table in `CLAUDE.md`. |
| **Codex CLI** | Skills are loaded by **`$skill-name` activation** — the agent reads the routing table in `AGENTS.md`, decides which skill applies, and activates it. |
| **Gemini CLI** | Skills are loaded by **explicit `ReadFile`** — the agent reads `GEMINI.md`, identifies the relevant skill path, and reads the file before editing. |

All three approaches achieve the same result: the agent loads expert context for the current task without reading 30 skill files upfront.

### Hooks *(Claude Code only)*

Hooks are shell scripts that Claude Code runs automatically at specific lifecycle events. They are defined in `.claude/settings.json` and installed into `.claude/hooks/`.

```
PreToolUse(Bash)    → pre-bash-guard.sh    → blocks dangerous commands (force-push, rm -rf, SQL DROP)
PostToolUse(Edit)   → format-on-save.sh    → runs your formatter (prettier / ruff / gofmt / etc.)
Stop                → notify-done.sh       → desktop notification when a session ends
PreCompact          → session-summary.sh   → saves a git diff snapshot before context is compacted
```

Codex and Gemini have no equivalent hook system — safety and formatting are handled by their approval modes and external CI.

### Rules *(Claude Code only)*

Rules are path-scoped Markdown files in `.claude/rules/`. Claude Code **automatically loads the relevant rule** when you open a file whose path matches the rule's `paths:` frontmatter — before you even start typing a prompt.

```
commit-style.md     → .github/, .gitignore       → Conventional Commits, one concern per PR
test-naming.md      → *.test.*, tests/            → No .only, no skip without issue link
migration-safety.md → migrations/, *.sql          → Reversible migrations, CONCURRENT indexes
env-safety.md       → .env*, config/, appsettings → No hardcoded secrets, .env.example required
```

Codex and Gemini follow the same principles, but they're embedded directly in `AGENTS.md` / `GEMINI.md` rather than as auto-loaded files.

### MCP servers *(all three tools)*

MCP (Model Context Protocol) is an open standard for giving agents access to external tools and data at runtime — databases, APIs, file systems, custom tools. All three CLIs support it, with different config locations:

- **Claude Code** — `.mcp.json` at the project root (strict JSON, stdio + HTTP/SSE transports). The kit installs an empty `{"mcpServers":{}}` plus a commented `.mcp.example.jsonc` reference with GitHub / filesystem / Postgres / Notion / Linear blocks to copy from. See [code.claude.com/docs/en/mcp](https://code.claude.com/docs/en/mcp).
- **Gemini CLI** — `mcpServers` block in `.gemini/settings.json`. See [the MCP server docs](https://google-gemini.github.io/gemini-cli/docs/tools/mcp-server.html).
- **Codex CLI** — `[mcp_servers.<name>]` tables in `.codex/config.toml`. See [the Codex MCP docs](https://developers.openai.com/codex/mcp).

> Note: `.mcp.json` must be **strict JSON** — Claude Code rejects comments. Edit `.mcp.example.jsonc` for reference, then paste comment-free blocks into `.mcp.json`.

### Subagents / Agents

All three tools support spawning specialized agents for focused sub-tasks (exploration, code review, security scan, test run, architecture). The kit ships five pre-configured agents per tool.

| Tool | Format | Location | Invocation |
|---|---|---|---|
| **Claude Code** | `.md` (frontmatter `name`/`description`/`tools`) | `.claude/agents/` | Agent tool in the main session |
| **Codex CLI** | `SKILL.md` (frontmatter `name`/`description`) | `.agents/skills/` | `/skills` or `$name` in the prompt |
| **Gemini CLI** | `.md` (frontmatter `name`/`description`/optional `tools`/`model`) | `.gemini/agents/` | `@agent-name` (native since April 2026) |

Subagents protect the main context window from noisy output (test logs, large diffs, exploration results).

#### Model selection strategy

Each agent is tuned for **task-appropriate cost** — the cheap models do the cheap work, the expensive models do the expensive work. The five shipped agents are wired as follows:

| Agent | Task | Claude | Codex effort | Gemini |
|---|---|---|---|---|
| `architect` | Deep design reasoning (rare, high stakes) | `claude-opus-4-7` | `high` | `gemini-2.5-pro` |
| `security-reviewer` | Vulnerability analysis (high stakes) | `claude-opus-4-7` | `high` | `gemini-2.5-pro` |
| `code-reviewer` | PR review (balanced) | `claude-sonnet-4-6` | `high` | `gemini-2.5-pro` |
| `codebase-investigator` | Grep / glob / read (frequent, simple) | `claude-haiku-4-5` | `medium` | `gemini-2.5-flash` |
| `test-runner` | Run tests + summarize (frequent, simple) | `claude-haiku-4-5` | `low` | `gemini-2.5-flash` |

**Rationale:** the two most frequently spawned agents (`codebase-investigator`, `test-runner`) handle work that doesn't require deep reasoning — searching the codebase, running shell commands, summarizing output. Using a small model for those tasks saves ~10× per invocation. The two highest-stakes agents (`architect`, `security-reviewer`) use the most capable model because the cost of a wrong call is much higher than the cost of the call itself. Override per project by editing the `model:` line in each agent file.

---

## Skill coverage

| Layer | Skills |
|---|---|
| Backend languages | `dotnet`, `java-kotlin`, `python`, `node`, `go`, `rust` |
| Frontend | `angular`, `vue`, `svelte`, `react` |
| Mobile | `mobile-rn` (React Native), `mobile-flutter` |
| Data | `database` (Postgres, MySQL, SQLite, MongoDB, Redis, ORM-agnostic) |
| Cross-cutting | `architecture`, `testing`, `code-review`, `security`, `dependencies`, `api-design`, `graphql`, `infrastructure`, `github-workflow` |
| Operational | `observability`, `messaging`, `error-handling`, `monorepo` |
| User-facing | `accessibility`, `i18n` |
| AI / LLM | `ai-dev` (RAG, tool use, agents, MCP, extended thinking, prompt caching, evals) |
| Performance | `performance` (profiling, benchmarking, Core Web Vitals, query optimization) |

Each skill lives in `skills/<name>/SKILL.md` and is lazy-loaded — only the relevant one is read for any given task.

Language / framework skills (`dotnet`, `go`, `rust`, `python`, `node`, `angular`, `vue`, `svelte`,
`react`, `mobile-flutter`, `mobile-rn`, `database`, `infrastructure`, `github-workflow`, `monorepo`,
`dependencies`, `graphql`) carry `paths:` frontmatter so Claude Code can auto-suggest the
skill when you open a matching file — no manual routing step needed in the project's `CLAUDE.md`.

Cross-cutting skills (`architecture`, `security`, `testing`, `code-review`, `observability`,
`messaging`, `error-handling`, `ai-dev`, `performance`, `accessibility`, `i18n`, `api-design`)
have no `paths:` — they are invoked explicitly via the routing table or on demand.

---

## Hooks *(Claude Code only)*

Four lifecycle hook scripts are installed into `.claude/hooks/` for Claude Code:

| Script | Event | What it does |
|---|---|---|
| `format-on-save.sh` | `PostToolUse(Edit\|Write)` | Runs your project's formatter (prettier / ruff / gofmt / rustfmt / dotnet format) on every file Claude writes |
| `pre-bash-guard.sh` | `PreToolUse(Bash)` | Blocks `git push --force`, `git reset --hard`, recursive `rm -rf` outside `/tmp`, and SQL `DROP` without an approval comment |
| `notify-done.sh` | `Stop` | Desktop notification when Claude finishes a session (macOS, Linux, Windows) |
| `session-summary.sh` | `PreCompact` | Saves a git status + diff snapshot to `.claude/session-log/` before context is compacted |

Hooks are referenced in `settings.json` and installed automatically by `install.sh` / `install.ps1`.

A `PreToolUse` hook returning **exit code 2** blocks the tool call and feeds its stderr back to Claude as a refusal message. All other hooks are async (fire-and-forget) and do not block the agent.

---

## Rules *(Claude Code only)*

Four path-scoped rule files are installed into `.claude/rules/` — Claude Code loads them automatically when you open a matching file:

| File | Triggers on | Enforces |
|---|---|---|
| `commit-style.md` | `.github/`, `.gitignore` | Conventional Commits, no force-push, one concern per commit |
| `test-naming.md` | `*.test.*`, `*.spec.*`, `tests/` | No `.only`, no skip without issue link, deterministic tests |
| `migration-safety.md` | `migrations/`, `*.sql`, `schema.prisma` | Reversible migrations, CONCURRENT indexes, no one-step column rename |
| `env-safety.md` | `.env*`, `config/`, `appsettings*.json` | No hardcoded secrets, `.env.example` required |

---

## MCP servers

A `.mcp.json` template is installed at your project root with commented examples for GitHub, filesystem, Postgres, Notion, and Linear MCP servers. Fill in the `${ENV_VAR}` placeholders and uncomment the servers you use.

MCP servers extend the agent with live access to external resources at runtime — without hardcoding tool logic into the prompt. A filesystem MCP server lets the agent browse files outside the workspace; a Postgres server lets it query your database directly.

See the [MCP specification](https://modelcontextprotocol.io) and `skills/ai-dev/SKILL.md` for implementation guidance.

---

## Prompts

The `prompts/` folder holds copy-paste starting points for common tasks. They are **not** copied into your project by the install script — open them in the kit and paste into your agent session.

| Prompt | When to use |
|---|---|
| `prompts/daily-ticket.md` | Starting a GitHub issue |
| `prompts/feature-planning.md` | Planning a multi-file feature |
| `prompts/bug-fix.md` | Reproducing and fixing a bug |
| `prompts/refactor.md` | Bounded refactor with no behavior change |
| `prompts/code-review.md` | Triage-style PR review |
| `prompts/run-tests.md` | Run + report the relevant test slice |
| `prompts/security-audit.md` | Targeted security pass |
| `prompts/on-call.md` | Live incident investigation + post-mortem |
| `prompts/dependency-update.md` | Safe single-package upgrade protocol |
| `prompts/tech-debt.md` | Triage and prioritize technical debt |
| `prompts/performance-audit.md` | Baseline → bottleneck → fix → re-measure |

### GitHub Actions templates

The `prompts/github-actions/` folder has ready-to-copy workflow files for AI-assisted CI. Each workflow listens for `@claude` / `@codex` / `@gemini` mentions in issues or PRs and triggers the corresponding AI agent to respond or review.

| File | Action | Use case |
|---|---|---|
| `claude-code.yml` | `anthropics/claude-code-action@v1` | `@claude` in issues / PRs / reviews |
| `codex-pr-review.yml` | `openai/codex-action@v1` | `@codex` in PR comments |
| `gemini-pr-review.yml` | `google-github-actions/run-gemini-cli@v0` | `@gemini` review in PR comments |
| `gemini-issue-triage.yml` | `google-github-actions/run-gemini-cli@v0` | Auto-triage new issues |

Copy these to `.github/workflows/` in your project (they are **not** installed automatically).

---

## Install vs update

| Script | Semantics |
|---|---|
| `install.ps1` / `install.sh` | **Always overwrites kit files** (skills, tooling configs, subagents, root `.md`). Reinstall to reset everything to baseline. |
| `update.ps1` / `update.sh` | **MD5-diff based** — only files that are missing or whose content differs are touched. Warns on version drift. Supports `--dry-run` / `-DryRun` to preview. |
| `uninstall.ps1` / `uninstall.sh` | Removes kit-installed files for the chosen tools. Preserves `docs/ai/`. |
| `validate.ps1` / `validate.sh` | Verifies `docs/ai/` templates have been filled (no `STOP` notices, no placeholder comments, all required files present). |
| `new-skill.ps1` / `new-skill.sh` | Scaffolds a new skill under `skills/<name>/` with the standard template — for kit contributors. |

**`docs/ai/` is never overwritten** by either install / update script — it holds your project-specific
content. To get fresh templates back, delete the folder manually before reinstalling.

Each install stamps a `.kit-version` file in your project root. `update` reads it to:
- Determine which tools were configured (so partial reinstalls work).
- Warn when the installed version differs from the source kit version.

---

## Adding a new skill

1. Scaffold it: `scripts/new-skill.sh --name <name>` (or `.ps1`).
2. Fill the placeholders in `skills/<name>/SKILL.md`.
3. If the skill is path-scoped, add `paths:` (and optionally `allowed-tools:`) to the frontmatter
   so Claude Code auto-loads it when matching files are opened.
4. Add a routing row in `tooling/{claude/CLAUDE.md, codex/AGENTS.md, gemini/GEMINI.md}`
   (needed for Codex, Gemini, and Claude Code's explicit routing table).
5. Add an entry to `CHANGELOG.md` under `[Unreleased] -> Added`.
6. Run the install or update script in your target projects to deploy.

---

## Example: filled `docs/ai/`

A complete reference of what filled templates look like — for a fictional
SaaS — is in `examples/filled-project/docs/ai/`. Use it as a model when
filling `docs/ai/` in your own project.

---

## Changelog

See [CHANGELOG.md](./CHANGELOG.md).
