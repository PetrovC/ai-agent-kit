# ai-agent-kit

A reusable, versioned AI agent configuration kit for Codex, Claude Code, and Gemini CLI.

## Philosophy

- One skill is written once and deployed to all tools.
- Root instruction files (AGENTS.md, CLAUDE.md, GEMINI.md) are short routers, not encyclopedias.
- Project context lives in `docs/ai/` inside each project — not in this kit.
- Subagents handle noisy, exploratory, or parallel work to protect the main context window.

## Structure

```
ai-agent-kit/
├── skills/               <- Tool-agnostic rules per stack/language/concern
├── tooling/              <- Tool-specific wrappers (Codex / Claude / Gemini)
│   ├── codex/agents/     <- Codex subagent definitions (.toml)
│   ├── claude/agents/    <- Claude subagent definitions (.md)
│   ├── claude/hooks/     <- Lifecycle hook scripts (format, guard, notify, summarize)
│   ├── claude/rules/     <- Path-scoped rules (commits, tests, migrations, env)
│   └── gemini/agents/    <- Gemini subagent definitions (.md)
├── project-template/     <- docs/ai/ templates to fill per project
├── prompts/              <- Reusable prompt templates
│   └── github-actions/   <- Copy-paste GitHub Actions workflow files
└── scripts/              <- Install / update / uninstall / validate scripts
```

## Quick start (5 minutes)

```powershell
# Windows
.\scripts\install.ps1 -Target "C:\path\to\your-project" -Tools codex,claude

# Linux / macOS
./scripts/install.sh --target /path/to/your-project --tools codex,claude
```

Then fill in `docs/ai/PROJECT.md` and `docs/ai/COMMANDS.md` in your project.

## Full kit (30 minutes)

1. Run the install script with all tools.
2. Fill every file in `docs/ai/` of the target project (each file starts with a STOP notice).
3. Run `validate.sh` / `validate.ps1` against the target — confirms templates were filled.
4. Customize skills for your project's stack.
5. Write your first ticket using a prompt from `prompts/` (see "Prompts" below).

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
| AI / LLM | `ai-dev` (RAG, tool use, agents, prompt caching, evals) |
| Performance | `performance` (profiling, benchmarking, Core Web Vitals, query optimization) |

Each skill lives in `skills/<name>/SKILL.md` and is lazy-loaded — only the relevant one is read for any given task.

Language / framework skills (`dotnet`, `go`, `rust`, `python`, `node`, `angular`, `vue`, `svelte`,
`react`, `mobile-flutter`, `mobile-rn`, `database`, `infrastructure`, `github-workflow`, `monorepo`,
`dependencies`, `graphql`) carry `paths:` frontmatter so Claude Code can auto-suggest the
skill when you open a matching file — no manual routing step needed in the project's CLAUDE.md.

Cross-cutting skills (`architecture`, `security`, `testing`, `code-review`, `observability`,
`messaging`, `error-handling`, `ai-dev`, `performance`, `accessibility`, `i18n`, `api-design`)
have no `paths:` — they are invoked explicitly via the CLAUDE.md / AGENTS.md / GEMINI.md routing
table or on demand.

## Hooks

Four lifecycle hook scripts are installed into `.claude/hooks/` for Claude Code:

| Script | Event | What it does |
|---|---|---|
| `format-on-save.sh` | `PostToolUse(Edit\|Write)` | Runs your project's formatter (prettier / ruff / gofmt / rustfmt / dotnet format) on every file Claude writes |
| `pre-bash-guard.sh` | `PreToolUse(Bash)` | Blocks `git push --force`, `git reset --hard`, recursive `rm -rf` outside `/tmp`, and SQL `DROP` without an approval comment |
| `notify-done.sh` | `Stop` | Desktop notification when Claude finishes a session (macOS, Linux, Windows) |
| `session-summary.sh` | `PreCompact` | Saves a git status + diff snapshot to `.claude/session-log/` before context is compacted |

Hooks are referenced in `settings.json` and installed automatically by `install.sh` / `install.ps1`.

## Rules

Four path-scoped rule files are installed into `.claude/rules/` — Claude Code loads them automatically when you open a matching file:

| File | Triggers on | Enforces |
|---|---|---|
| `commit-style.md` | `.github/`, `.gitignore` | Conventional Commits, no force-push, one concern per commit |
| `test-naming.md` | `*.test.*`, `*.spec.*`, `tests/` | No `.only`, no skip without issue link, deterministic tests |
| `migration-safety.md` | `migrations/`, `*.sql`, `schema.prisma` | Reversible migrations, CONCURRENT indexes, no one-step column rename |
| `env-safety.md` | `.env*`, `config/`, `appsettings*.json` | No hardcoded secrets, `.env.example` required |

## MCP servers

A `.mcp.json` template is installed at your project root with commented examples for GitHub, filesystem, Postgres, Notion, and Linear MCP servers. Fill in the `${ENV_VAR}` placeholders and uncomment the servers you use.

## Prompts

The `prompts/` folder holds copy-paste starting points for common tasks:

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

The `prompts/github-actions/` folder has ready-to-copy workflow files for AI-assisted CI:

| File | Action | Use case |
|---|---|---|
| `claude-code.yml` | `anthropics/claude-code-action@v1` | @claude in issues / PRs / reviews |
| `codex-pr-review.yml` | `openai/codex-action@v1` | @codex in PR comments |
| `gemini-pr-review.yml` | `google-github-actions/run-gemini-cli@v0` | @gemini review in PR comments |
| `gemini-issue-triage.yml` | `google-github-actions/run-gemini-cli@v0` | Auto-triage new issues |

Copy these to `.github/workflows/` in your project (they are **not** installed automatically).

Prompts are **not** copied into your project by the install script — open them in the kit and paste into your agent.

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

## Adding a new skill

1. Scaffold it: `scripts/new-skill.sh --name <name>` (or `.ps1`).
2. Fill the placeholders in `skills/<name>/SKILL.md`.
3. If the skill is path-scoped, add `paths:` (and optionally `allowed-tools:`) to the frontmatter
   so Claude Code auto-loads it when matching files are opened.
4. Add a routing row in `tooling/{claude/CLAUDE.md, codex/AGENTS.md, gemini/GEMINI.md}`
   (still needed for Codex, Gemini, and Claude Code's explicit routing table).
5. Add an entry to `CHANGELOG.md` under `[Unreleased] -> Added`.
6. Run the install or update script in your target projects to deploy.

## Example: filled `docs/ai/`

A complete reference of what filled templates look like — for a fictional
SaaS — is in `examples/filled-project/docs/ai/`. Use it as a model when
filling `docs/ai/` in your own project.

## Changelog

See [CHANGELOG.md](./CHANGELOG.md).
