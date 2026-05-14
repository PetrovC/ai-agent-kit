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
│   └── gemini/agents/    <- Gemini subagent definitions (.md)
├── project-template/     <- docs/ai/ templates to fill per project
├── prompts/              <- Reusable prompt templates
└── scripts/              <- Install / update scripts
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
| Backend languages | `dotnet`, `python`, `node`, `go`, `rust` |
| Frontend | `angular`, `vue`, `react` |
| Mobile | `mobile-rn` (React Native), `mobile-flutter` |
| Data | `database` (Postgres, MySQL, SQLite, MongoDB, Redis, ORM-agnostic) |
| Cross-cutting | `architecture`, `testing`, `code-review`, `security`, `dependencies`, `api-design`, `infrastructure`, `github-workflow` |
| Operational | `observability`, `messaging`, `error-handling`, `monorepo` |
| User-facing | `accessibility`, `i18n` |
| AI / LLM | `ai-dev` (RAG, tool use, agents, prompt caching, evals) |

Each skill lives in `skills/<name>/SKILL.md` and is lazy-loaded — only the relevant one is read for any given task.

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
3. Add a routing row in `tooling/{claude/CLAUDE.md, codex/AGENTS.md, gemini/GEMINI.md}`.
4. Add an entry to `CHANGELOG.md` under `[Unreleased] -> Added`.
5. Run the install or update script in your target projects to deploy.

## Example: filled `docs/ai/`

A complete reference of what filled templates look like — for a fictional
SaaS — is in `examples/filled-project/docs/ai/`. Use it as a model when
filling `docs/ai/` in your own project.

## Changelog

See [CHANGELOG.md](./CHANGELOG.md).
