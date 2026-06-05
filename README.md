# ai-agent-kit

[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/PetrovC/ai-agent-kit/badge)](https://securityscorecards.dev/viewer/?uri=github.com/PetrovC/ai-agent-kit)
[![Quality gate](https://github.com/PetrovC/ai-agent-kit/actions/workflows/quality-gate.yml/badge.svg)](https://github.com/PetrovC/ai-agent-kit/actions/workflows/quality-gate.yml)
[![OpenSSF Scorecard workflow](https://github.com/PetrovC/ai-agent-kit/actions/workflows/scorecard.yml/badge.svg)](https://github.com/PetrovC/ai-agent-kit/actions/workflows/scorecard.yml)
![GitHub License](https://img.shields.io/github/license/PetrovC/ai-agent-kit)
![GitHub release](https://img.shields.io/github/v/release/PetrovC/ai-agent-kit)
![GitHub last commit](https://img.shields.io/github/last-commit/PetrovC/ai-agent-kit)

A reusable, versioned AI agent configuration kit for Claude Code, Codex CLI, and Antigravity CLI.

## Philosophy

- One skill is written once and deployed to all tools.
- Root instruction files (`AGENTS.md`, `CLAUDE.md`, `AGY.md`) are short routers, not encyclopedias.
- Project context lives in `docs/ai/` inside each project — not in this kit.
- Subagents handle noisy, exploratory, or parallel work to protect the main context window.

This repository intentionally dogfoods the kit for Claude Code and Codex CLI:
`AGENTS.md`, `CLAUDE.md`, `.agents/`, `.claude/`, `.codex/`, `.mcp.json`,
`.mcp.example.jsonc`, `.kit-version`, `.kit-manifest`, and `docs/ai/` are
tracked here as project-local configuration. Antigravity root install output and
Claude local/runtime files stay ignored.

---

## Contributing

Start with [CONTRIBUTING.md](CONTRIBUTING.md) for the issue-first workflow,
branch and commit conventions, Definition of Done, and local validation
commands.

---

## Choose Your Install

| Path | Use when | What it installs |
|---|---|---|
| **Install script** | You want the full kit for Claude Code, Codex CLI, Antigravity CLI, or more than one tool. | Tool routers, shared skills, commands, agents, hooks where supported, MCP examples, and `docs/ai/` project context. |
| **Claude plugin marketplace** | You only use Claude Code and want the skills slice with no project scaffolding. | Namespaced Claude skills only. Run `/plugin marketplace add PetrovC/ai-agent-kit`, then `/plugin install ai-agent-kit@ai-agent-kit`. |
| **Antigravity extension scaffold** | You are building a custom Antigravity CLI extension distribution. | A maintained starting point under `tooling/agy/`; the script remains the canonical full install path. |

### Tool x OS Support

| Tool | Linux | macOS | Windows |
|---|---|---|---|
| **Claude Code** | Script install supported; plugin marketplace is available for skills-only installs. | Script install supported; plugin marketplace is available for skills-only installs. | PowerShell script install supported. Hooks require Git Bash utilities; plugin marketplace remains skills-only. |
| **Codex CLI** | Script install supported. | Script install supported. | PowerShell script install supported. Hooks are wired through the PowerShell wrapper and still need Git Bash available. |
| **Antigravity CLI** | Script install supported; `pre-bash-guard` `BeforeTool` hook deployed. | Script install supported; `pre-bash-guard` `BeforeTool` hook deployed. | PowerShell script install supported; `pre-bash-guard` `BeforeTool` hook deployed (uses Git Bash, same as Claude/Codex on Windows). |

Known Windows limitations are called out below: ExecutionPolicy can block `.ps1`
files unless you use the bypass form, and hook wrappers need real Git Bash
rather than the WSL `bash.exe` launcher. Maintainer command notes live in
[docs/ai/COMMANDS.md](docs/ai/COMMANDS.md); Windows hook diagnostics are also
tracked in [docs/ai/CONTEXT_SANITIZATION.md](docs/ai/CONTEXT_SANITIZATION.md).

---

## Official resources

The tools this kit targets, and their official documentation:

| Tool | Source | Docs / Reference |
|---|---|---|
| **Claude Code** (Anthropic) | [github.com/anthropics/claude-code](https://github.com/anthropics/claude-code) | All Anthropic repos: [github.com/orgs/anthropics/repositories](https://github.com/orgs/anthropics/repositories) |
| **Codex CLI** (OpenAI) | [github.com/openai/codex](https://github.com/openai/codex) | GitHub Action: [github.com/openai/codex-action](https://github.com/openai/codex-action) |
| **Antigravity CLI** (Google) | [github.com/google-antigravity/antigravity-cli](https://github.com/google-antigravity/antigravity-cli) | Docs: [antigravity.google/docs](https://antigravity.google/docs) |

---

## Structure

```
ai-agent-kit/
├── .claude-plugin/       <- Claude plugin + marketplace manifests (opt-in, skills only)
├── skills/               <- Tool-agnostic rules per stack/language/concern
├── tooling/              <- Tool-specific wrappers (Codex / Claude / Antigravity)
│   ├── codex/skills/     <- Codex subagent skills (SKILL.md, installed into .agents/skills/)
│   ├── codex/hooks/      <- Codex lifecycle hooks (guard, format, notify) + hooks.json
│   ├── claude/agents/    <- Claude subagent definitions (.md)
│   ├── claude/commands/  <- Claude slash commands (.md, installed into .claude/commands/)
│   ├── claude/hooks/     <- Lifecycle hook scripts (format, guard, notify, summarize)
│   ├── claude/rules/     <- Path-scoped rules (commits, tests, migrations, env)
│   ├── agy/agents/       <- Antigravity subagent definitions (.md)
│   └── agy/commands/     <- Antigravity slash commands (.toml, installed into .agy/commands/)
├── project-template/     <- docs/ai/ templates to fill per project
├── prompts/              <- Reference prompt templates (canonical source for slash commands)
│   └── github-actions/   <- Copy-paste GitHub Actions workflow files
└── scripts/              <- Install / update / uninstall / validate scripts
```

**Key design principle:** `skills/` is tool-agnostic in **content** — the same `skills/dotnet/SKILL.md` is installed into `.agents/skills/` (Codex), `.claude/skills/` (Claude Code), and `.agy/skills/` (Antigravity CLI) by the install script, and its prose contains no Claude-specific / Codex-specific / Antigravity-specific instructions. Tool-specific *behaviour* (hooks, config syntax, agent format) lives exclusively in `tooling/`.

The shared-skill **YAML frontmatter** may carry two Claude-recognized hints:

- `paths:` — Claude Code uses this to auto-load the skill when a matching file is opened.
- `allowed-tools:` — Claude Code uses this to pre-approve specific `Bash(...)` commands so the skill can run them without per-call confirmation.

These are deliberately treated as **shared metadata that other tools ignore**. Codex and Antigravity do not read either field; they route by the table in `AGENTS.md` / `AGY.md` and inherit the user's approval mode. Putting these fields here (instead of behind a Claude-only overlay) keeps every skill exactly one file across all three installs — the cost is that the kit's "tool-agnostic" property applies to skill *content*, not to skill frontmatter. See `skills/README.md` for the full contract.

---

## Quick start (5 minutes)

### Option A — install script (canonical, all 3 tools)

The script is the only path that configures all three tools (Codex, Claude and
Antigravity), installs hooks/commands, and scaffolds `docs/ai/` — Codex in
particular has no marketplace mechanism, so files must be placed in the repo.

```powershell
# Windows — all 3 tools (omit -Tools to get the same default)
.\scripts\install.ps1 -Target "C:\path\to\your-project" -Tools codex,claude,agy

# Linux / macOS — all 3 tools (omit --tools to get the same default)
./scripts/install.sh --target /path/to/your-project --tools codex,claude,agy
```

Then fill in `docs/ai/PROJECT.md` and `docs/ai/COMMANDS.md` in your project.

#### Governance templates

A full install (`--profile full`, the default) also copies five governance policy
templates into your project's `docs/ai/` directory:

| File | Purpose | Fill in |
|---|---|---|
| `CONTEXT_GOVERNANCE.md` | Context thresholds, compaction policy, router budgets | Team-specific thresholds, project CI commands |
| `SUBAGENT_GOVERNANCE.md` | When to delegate vs. work inline; no-duplicate-reading rules | Project-specific subagent registry |
| `MCP_POLICY.md` | Which MCP servers are allowed, scopes, approval process | Your approved server list |
| `MODEL_ROUTING.md` | Model selection rules per task complexity | Your preferred models |
| `CONTEXT_SANITIZATION.md` | What must never appear in briefs or logs | Project-specific secrets and PII patterns |

Each file is **project-owned** — the kit never overwrites them after the first
install. Edit them to match your team's standards. The templates contain
`<!-- TODO: fill in -->` markers to guide customization.

#### Pinning to a release

To install from a specific tagged release rather than `master`:

```bash
# Clone at a specific tag
git clone --branch v1.21.0 --depth 1 <repo-url> ai-agent-kit-kit
cd ai-agent-kit-kit
./scripts/install.sh --target /path/to/your-project --tools codex,claude,agy
```

Tagged releases are listed on the Releases page. Using a tag ensures your
install is reproducible — `master` may include unreleased changes.

For the plugin marketplace (Option B), pinning is not yet supported; the
marketplace always installs from `master`.

#### Verifying a release

Each release ships a `SHA256SUMS` file and a cosign signature bundle
(`SHA256SUMS.bundle`). Download both from the Releases page and run:

```bash
sha256sum --check --ignore-missing SHA256SUMS
cosign verify-blob SHA256SUMS --bundle SHA256SUMS.bundle \
  --certificate-identity-regexp ".*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
```

#### Windows notes

For full Windows hook setup guidance, see [docs/ai/WINDOWS_HOOKS.md](docs/ai/WINDOWS_HOOKS.md).

For maintainer-side command references and hook diagnostics, see
[docs/ai/COMMANDS.md](docs/ai/COMMANDS.md) and
[docs/ai/CONTEXT_SANITIZATION.md](docs/ai/CONTEXT_SANITIZATION.md).

- **PowerShell ExecutionPolicy.** A default Windows install ships with
  `Restricted`, which refuses to run script files
  ([about_Execution_Policies](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies)).
  Direct invocation (`.\scripts\install.ps1 …`) fails with
  *"Impossible de charger le fichier … car l'exécution de scripts est
  désactivée sur ce système"* / *"… cannot be loaded because running scripts
  is disabled on this system."* Bypass it for the single run without
  changing the machine policy:

  ```powershell
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Target "C:\path\to\your-project" -Tools codex,claude,agy
  # or, on PowerShell 7+:
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Target "C:\path\to\your-project" -Tools codex,claude,agy
  ```

  The same form applies to `update.ps1`, `validate.ps1`, `uninstall.ps1`,
  and `new-skill.ps1`. If you'd rather change the policy persistently for
  the current user, see Microsoft's guide above — `Set-ExecutionPolicy
  RemoteSigned -Scope CurrentUser` is the usual relaxed setting.

- **Hooks still need real Git Bash, but PowerShell installs no longer rely on
  ambiguous `bash` resolution.** The Bash hooks use Git Bash utilities such as
  `cat`, `grep`, `sed`, and optionally `jq`/`python3`. On Windows, raw `bash`
  commands can resolve to:
  - `C:\Program Files\Git\bin\bash.exe` — Git Bash, ships
    `cat`/`grep`/`sed`/`jq`/`python3`-style utilities the hooks need. **Works.**
  - `C:\Windows\System32\bash.exe` — the WSL launcher stub. If no WSL
    distro is installed it prints a *"Windows Subsystem for Linux has
    no installed distributions"* error and exits non-zero. The
    `pre-bash-guard` PreToolUse hook then silently never runs, so destructive-
    command interception is lost without any visible signal. **Does not work.**

  PowerShell installs wire Claude / Codex hooks through `run-hook.ps1`, which
  prefers Git Bash from `%ProgramFiles%\Git\bin\bash.exe` before falling back
  to PATH. If you install through Bash on Windows, or hand-edit hook commands,
  make sure Git Bash precedes WSL `bash.exe` on the system `PATH`
  (`%ProgramFiles%\Git\bin` before `%SystemRoot%\System32`). Verify in a fresh
  terminal:

  ```cmd
  where bash
  bash --version
  ```

  For PowerShell-installed projects, the wrapper should resolve Git Bash even
  when PATH is imperfect. For Bash-installed or manually edited projects, both
  commands should resolve to Git Bash. The hooks are guardrails, not a sandbox,
  but losing them removes the kit's mechanical block against common destructive
  shell mistakes.

### Option B — Claude plugin marketplace (opt-in, skills only)

If you only use Claude Code and just want the **31 skills** (no Codex/Antigravity
config, no `docs/ai/` scaffolding), install via the plugin marketplace:

```text
/plugin marketplace add PetrovC/ai-agent-kit
/plugin install ai-agent-kit@ai-agent-kit
```

Skills become available namespaced (`/ai-agent-kit:dotnet`, …) and `paths:`
auto-loading still works. This does **not** replace the script — it's the
skills slice only, for the single-tool case. For hooks, slash commands, Codex,
Antigravity, or `docs/ai/`, use Option A.

> **Private repo:** this works even when the repo is private — Claude Code
> clones the marketplace with *your* git credentials. Anyone running
> `/plugin marketplace add` must have read access to the repo (be a
> collaborator, or authenticated `gh`/git). The plugin `source` is `"./"`
> (same-repo relative path), so the plugin is served from that one
> authenticated clone — no second fetch that could fail on a private repo.

#### Pinning and pre-enabling the plugin (team setup)

For teams where everyone should have the plugin active and no unapproved
plugins should be installable, add these two keys to the project
`settings.json` (or `CLAUDE.local.json` for personal overrides):

```json
{
  "strictKnownMarketplaces": true,
  "enabledPlugins": ["PetrovC/ai-agent-kit@ai-agent-kit"]
}
```

- **`strictKnownMarketplaces: true`** — Claude Code will only allow installing
  plugins from sources already listed in your `settings.json` marketplace
  entries. Prevents accidental installs from unknown sources.
- **`enabledPlugins`** — list of plugin IDs that are automatically active for
  every session. The format is `<org>/<repo>@<plugin-name>`, which matches the
  values you pass to `/plugin install`.

> **Note:** `enabledPlugins` does not replace `/plugin marketplace add` on each
> machine; it is a session-activation shortcut — the marketplace source must
> still be present (or be resolvable from the repo clone). Use it alongside a
> shared `settings.json` committed to the project.

### Optional artifacts (not auto-installed, by design)

Two maintained files are intentionally **not** placed by the install script —
they target a *user home directory* or a *distribution channel*, not a project:

| File | What it's for | How to use it |
|---|---|---|
| `tooling/codex/global-config-template.toml` | Personal Codex prefs (model, reasoning effort, `readonly`/`standard`/`deep`/`review` profiles, Windows sandbox) — the per-user `~/.codex/config.toml`, not a project file | `cp tooling/codex/global-config-template.toml ~/.codex/config.toml` then edit |
| `tooling/agy/agy-extension.json` | Scaffold for teams who want to distribute the kit as an installable **Antigravity CLI extension** (`agy extensions install`) instead of via the script | Starting point — extend with your skills/commands, then publish per the [Antigravity extensions docs](https://antigravity.google/docs/extensions) |

`agy-extension.json`'s `version` is still pinned to root `VERSION` by CI so it
never drifts, even though install/update/uninstall deliberately ignore both files.

> **Extension-mode caveat (Antigravity only).** When the kit is distributed via
> `agy extensions install`, only the files Antigravity natively loads from the
> extension folder (`commands/`, `agents/`, the `contextFileName`) reach the
> user's project. The routing table inside the installed `AGY.md` still
> references project-relative paths like `.agy/skills/python/SKILL.md`, but
> the extension doesn't copy `.agy/skills/` into the user's project — those
> files live under `~/.agy/extensions/ai-agent-kit/skills/` instead.
> Effect: in Extension mode the kit's commands and subagents work, but skill
> activation via the routing table will fail with "File not found". For full
> skill coverage, either run the install script in addition to the extension,
> or fork the extension and inline the skills you actually use into the
> shipped `AGY.md`. The install script remains the canonical multi-tool
> setup; the extension scaffold is here for teams who explicitly want the
> `agy extensions install` distribution channel for their commands and
> agents.

### Codex long-run mode

The Codex operating checklist lives in
[`tooling/codex/AGENTS.md`](tooling/codex/AGENTS.md) and installs as project
`AGENTS.md`. It keeps the root router short while pointing long-running
sessions to [context governance](docs/ai/CONTEXT_GOVERNANCE.md),
[model routing](docs/ai/MODEL_ROUTING.md), and
[subagent governance](docs/ai/SUBAGENT_GOVERNANCE.md).

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
| **Antigravity CLI** | Skills under `.agy/skills/<name>/SKILL.md` are **Native Agent Skills** — Antigravity auto-discovers them at session start and activates by `description:` frontmatter. The routing table in `AGY.md` is kit policy for deterministic activation (so the choice doesn't drift with description-matching heuristics). Verify discovery with `/skills` or `agy skills list`. |

All three approaches achieve the same result: the agent loads expert context for the current task without reading 30 skill files upfront.

### Hooks *(Claude Code + Codex CLI)*

Hooks are shell scripts run automatically at lifecycle events. Claude Code
wires them via `.claude/settings.json` (installed into `.claude/hooks/`);
Codex via `.codex/hooks.json` (installed into `.codex/hooks/`). Both use the
same model: stdin JSON, exit code 2 = block.

```
Claude  PreToolUse(Bash)        → pre-bash-guard.sh   → blocks force/mirror/delete push, ref deletion, destructive `git switch`, `git clean -f`, rm -rf, SQL DROP
        PostToolUse(Edit|Write) → format-on-save.sh   → runs your formatter
        Stop                    → notify-done.sh      → desktop notification
        PreCompact              → session-summary.sh  → git diff snapshot before compaction
Codex   PreToolUse(Bash)        → pre-bash-guard.sh   → same hardened guard
        PostToolUse(edit)       → format-on-save.sh   → formats changed files
        Stop                    → notify-done.sh      → desktop notification
```

Codex has no `PreCompact` event, so `session-summary` is Claude-only. Antigravity
gets the `pre-bash-guard` `BeforeTool` hook (same denylist as Claude/Codex);
`format-on-save`, `notify-done`, and `session-summary` for Antigravity are not in
this release (the relevant `tool_input` / event payload schemas need to be
confirmed against live Antigravity behaviour first). See the detailed Hooks
section further down for the exact behaviour.

### Rules *(Claude Code only)*

Rules are path-scoped Markdown files in `.claude/rules/`. Claude Code **automatically loads the relevant rule** when you open a file whose path matches the rule's `paths:` frontmatter — before you even start typing a prompt.

```
test-naming.md      → *.test.*, tests/            → No .only, no skip without issue link
migration-safety.md → migrations/, *.sql          → Reversible migrations, CONCURRENT indexes
env-safety.md       → .env*, config/, appsettings → No hardcoded secrets, .env.example required
```

Commit-message rules (Conventional Commits, one concern per commit, never-commit
list) live directly in `CLAUDE.md`/`AGENTS.md`/`AGY.md` `## Git rules` so they
apply to **every** commit — not only when editing files under `.github/`.

Codex and Antigravity follow the same principles, but they're embedded directly in `AGENTS.md` / `AGY.md` rather than as auto-loaded files.

### MCP servers *(all three tools)*

MCP (Model Context Protocol) is an open standard for giving agents access to external tools and data at runtime — databases, APIs, file systems, custom tools. All three CLIs support it, with different config locations:

- **Claude Code** — `.mcp.json` at the project root (strict JSON, stdio + HTTP/SSE transports). On first install the kit bootstraps an empty `{"mcpServers":{}}`; afterwards `.mcp.json` is project-owned — install reruns skip it, update never overwrites it, and uninstall preserves it (same policy as `docs/ai/`). The kit ships `.mcp.example.jsonc` as the versioned reference with GitHub / filesystem / Postgres / Notion / Linear blocks to copy from. See [code.claude.com/docs/en/mcp](https://code.claude.com/docs/en/mcp).
- **Antigravity CLI** — `mcpServers` block in `.agy/settings.json`. See [the MCP server docs](https://antigravity.google/docs/tools/mcp-server.html).
- **Codex CLI** — `[mcp_servers.<name>]` tables in `.codex/config.toml`. See [the Codex MCP docs](https://developers.openai.com/codex/mcp).

> Note: `.mcp.json` must be **strict JSON** — Claude Code rejects comments. Edit `.mcp.example.jsonc` for reference, then paste comment-free blocks into `.mcp.json`.

### Subagents / Agents

All three tools support spawning specialized agents for focused sub-tasks (exploration, code review, security scan, test run, architecture). The kit ships five pre-configured agents per tool.

| Tool | Format | Location | Invocation |
|---|---|---|---|
| **Claude Code** | `.md` (frontmatter `name`/`description`/`tools`) | `.claude/agents/` | Agent tool in the main session |
| **Codex CLI** | `SKILL.md` (frontmatter `name`/`description`) | `.agents/skills/` | `/skills` or `$name` in the prompt |
| **Antigravity CLI** | `.md` (frontmatter `name`/`description`/optional `tools`/`model`) | `.agy/agents/` | `@agent-name` (native since April 2026) |

Subagents protect the main context window from noisy output (test logs, large diffs, exploration results).

#### Model selection strategy

All five agents run on the **most capable model** so every report —
investigation, test summary, review, design — is high quality and directly
actionable. Uniform tier, no exceptions:

| Agent | Task | Claude | Antigravity |
|---|---|---|---|
| `architect` | Deep design reasoning | `claude-opus-4-8` | `gemini-3.1-pro` |
| `security-reviewer` | Vulnerability analysis | `claude-opus-4-8` | `gemini-3.1-pro` |
| `code-reviewer` | PR review | `claude-opus-4-8` | `gemini-3.1-pro` |
| `codebase-investigator` | Map usages / affected area | `claude-sonnet-4-6` | `gemini-3-flash` |
| `test-runner` | Run tests + summarize | `claude-haiku-4-5` | `gemini-3-flash` |

**Codex** does not pin a model per skill — the official Codex skill spec is
`SKILL.md` with `name` + `description` only, so the five Codex agent-skills run
on the **session model** (set in `~/.codex/config.toml` or `--model`). The
behavioural role is identical across all three tools.

**Rationale:** decision-bearing agents (`architect`, `security-reviewer`,
`code-reviewer`) use the strongest available model — report quality matters more
than token cost for high-stakes output. Mechanical agents (`codebase-investigator`,
`test-runner`) use a balanced/fast model since their output is narrow and
deterministic. Token efficiency still comes from **lazy-loaded skills** and
**short routers**, not from over-tiering. Override per project by editing the
`model:` line in each agent file.

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

## Hooks *(Claude Code + Codex CLI)*

Lifecycle hook scripts run automatically at tool events. Claude Code wires them
via `.claude/settings.json`; Codex via `.codex/hooks.json`. Both use the same
model (stdin JSON, exit 2 = block).

**Claude Code** — installed into `.claude/hooks/`:

| Script | Event | What it does |
|---|---|---|
| `format-on-save.sh` | `PostToolUse(Edit\|Write)` | Runs your project's formatter (prettier / ruff / gofmt / rustfmt / dotnet format) on every file written |
| `pre-bash-guard.sh` | `PreToolUse(Bash)` | Blocks force/mirror/delete push (incl. `+refspec`), `git branch -D` / `-d -f` / `-fd` / `update-ref -d`, `git reset --hard`/`--keep`, destructive `git switch` (`--discard-changes`/`--force`/`-f`/`-C`/`--force-create`), `git clean -f` (and `-fd`/`-fdx`/`--force` variants — `-n` / `--dry-run` stays allowed), recursive `rm -rf` on absolute/home/parent/cwd/glob/variable targets, and SQL `DROP` without an approval comment. Git global options (`git -C dir`, `-c key=val`, `--git-dir=`, `--work-tree=`) before the destructive subcommand are covered. **Best-effort denylist, not a sandbox** — see the script header for the honest limits |
| `notify-done.sh` | `Stop` | Desktop notification when a session finishes (macOS, Linux, Windows) |
| `session-summary.sh` | `PreCompact` | Saves a git status + diff snapshot to `.claude/session-log/` before context is compacted |

**Codex CLI** — installed into `.codex/hooks/` (wired by `.codex/hooks.json`):

| Script | Event | What it does |
|---|---|---|
| `pre-bash-guard.sh` | `PreToolUse(Bash)` | Same hardened guard as Claude |
| `format-on-save.sh` | `PostToolUse(Edit\|Write\|Patch)` | Same formatter dispatch |
| `notify-done.sh` | `Stop` | Desktop notification |

Codex has no `PreCompact` event, so `session-summary` is Claude-only. The guard
parses hook input via a `jq → python3 → sed` fallback chain: a missing or broken
interpreter (e.g. the Windows python3 stub) yields empty output and falls through
to the next parser. If all three return empty (unknown schema, missing
`tool_input.command` field, malformed JSON), the guard refuses the call with
exit 2 instead of authorizing what it could not inspect.

All hooks are installed automatically by `install.sh` / `install.ps1`.

A `PreToolUse` hook returning **exit code 2** blocks the tool call and feeds its stderr back to Claude as a refusal message. All other hooks are async (fire-and-forget) and do not block the agent.

---

## Rules *(Claude Code only)*

Three path-scoped rule files are installed into `.claude/rules/` — Claude Code loads them automatically when you open a matching file:

| File | Triggers on | Enforces |
|---|---|---|
| `test-naming.md` | `*.test.*`, `*.spec.*`, `tests/` | No `.only`, no skip without issue link, deterministic tests |
| `migration-safety.md` | `migrations/`, `*.sql`, `schema.prisma` | Reversible migrations, CONCURRENT indexes, no one-step column rename |
| `env-safety.md` | `.env*`, `config/`, `appsettings*.json` | No hardcoded secrets, `.env.example` required |

---

## MCP servers

On first install an empty `.mcp.json` (strict JSON) is created at your project root, and the commented `.mcp.example.jsonc` reference is installed alongside it with examples for GitHub, filesystem, Postgres, Notion, and Linear MCP servers. Paste comment-free server blocks from `.mcp.example.jsonc` into `.mcp.json` and fill in the `${ENV_VAR}` placeholders. After that first install `.mcp.json` is yours: subsequent `install`, `update`, and `uninstall` runs leave it untouched.

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

The `prompts/github-actions/` folder has ready-to-copy workflow files for AI-assisted CI. Each workflow listens for `@claude` / `@codex` mentions in issues or PRs and triggers the corresponding AI agent to respond or review.

| File | Action | Use case |
|---|---|---|
| `claude-code.yml` | `anthropics/claude-code-action@v1` | `@claude` in issues / PRs / reviews |
| `codex-pr-review.yml` | `openai/codex-action@v1` | `@codex` in PR comments |
| `ai-fallback-dispatch.yml` | both actions, chained | Label an issue `ai-fallback` → Claude→Codex implement it; the chain advances only until one lands a PR |

Copy these to `.github/workflows/` in your project (they are **not** installed automatically).

> **Supply chain:** the templates reference each action by **major-version tag** (`@v1`,
> `actions/checkout@v4`, …). Tags are mutable refs that the action owner can
> move, so this is "lightly pinned for maintainability" — *not* the immutable
> SHA-pinning GitHub's
> [supply-chain hardening guide](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions)
> recommends for jobs with write scopes. For stricter pinning, replace each
> `@vN` with the full commit SHA from the action's releases page (and bump
> deliberately during review). The kit ships tags because most adopters will
> want the maintainability over the supply-chain strictness; pick the trade-off
> that fits your threat model.

> **`ai-fallback-dispatch.yml`** is the resilient one: it runs both
> agents *sequentially on the same branch* and only hands off when a provider
> did **not** finish. "Finished" is an observable git fact (a non-draft PR
> whose head is `ai/issue-<N>` and whose body says `Closes #<N>`), never an
> exit code — so a provider running out of tokens/quota yields to the next
> instead of blocking the issue. Re-runs are idempotent (the gate short-
> circuits once the PR exists). It needs both API-key secrets; drop a
> provider's step if you only have one.

---

## Install vs update

| Script | Semantics |
|---|---|
| `install.ps1` / `install.sh` | **Always overwrites kit files** (skills, tooling configs, subagents, root `.md`). Reinstall to reset everything to baseline. |
| `update.ps1` / `update.sh` | **Content-diff based** — only files that are missing or whose content differs are touched. `update.sh` also **prunes** files the kit no longer ships, via a `.kit-manifest` diff (scoped to `--tools`, never `docs/ai/` or user files; PowerShell parity tracked separately). Warns on version drift. Supports `--dry-run` / `-DryRun` to preview. |
| `uninstall.ps1` / `uninstall.sh` | Removes only kit-installed files for the chosen tools, using `.kit-manifest` as the source of truth. User files added inside managed dirs (e.g. `.claude/agents/team-agent.md`, `.claude/settings.local.json`) are preserved. Falls back to a reconstructed file list when no manifest is present. Preserves `docs/ai/`. |
| `validate.ps1` / `validate.sh` | Verifies `docs/ai/` templates have been filled, guards Codex router context budget plus context/model/subagent link hygiene, prints a compact largest Codex-facing file summary, and in this source repo flags Claude/Codex dogfood drift from `tooling/` or `skills/`. |
| `new-skill.ps1` / `new-skill.sh` | Scaffolds a new skill under `skills/<name>/` with the standard template — for kit contributors. |
| `doctor.ps1` / `doctor.sh` | Diagnoses target project installation health (missing files, manifest drift, outdated version, non-executable hooks, docs/ai and MCP example presence). |

**`docs/ai/` is never overwritten** by either install / update script — it holds your project-specific
content. To get fresh templates back, delete the folder manually before reinstalling.

Each install stamps a `.kit-version` file in your project root. `update` reads it to:
- Determine which tools were configured (so partial reinstalls work).
- Warn when the installed version differs from the source kit version.

Install also writes a `.kit-manifest` (the list of kit-managed paths). `update.sh`
diffs the new shipped set against it and prunes anything the kit stopped shipping
— so a renamed/removed skill or command no longer lingers as a stale file. The
first update after upgrading to this version just establishes the baseline
(nothing is pruned until there is a manifest to diff against).

---

## Adding a new skill

1. Scaffold it: `scripts/new-skill.sh --name <name>` (or `.ps1`).
2. Fill the placeholders in `skills/<name>/SKILL.md`.
3. If the skill is path-scoped, add `paths:` (and optionally `allowed-tools:`) to the frontmatter
   so Claude Code auto-loads it when matching files are opened.
4. Add a routing row in `tooling/{claude/CLAUDE.md, codex/AGENTS.md, agy/AGY.md}`
   (needed for Codex, Antigravity, and Claude Code's explicit routing table).
5. Add an entry to `CHANGELOG.md` under `[Unreleased] -> Added`.
6. Run the install or update script in your target projects to deploy.

---

## Example: filled `docs/ai/`

A complete reference of what filled templates look like — for a fictional
SaaS — is in `examples/filled-project/docs/ai/`. Use it as a model when
filling `docs/ai/` in your own project.

---

## Security posture

This repository uses several automated guardrails and visibility signals:

- **OpenSSF Scorecard** — supply-chain security posture, visible in the badge above.
- **GitHub Actions quality gate** — pull request validation (scripts, hooks, install, parity, manifest).
- **GitHub Dependabot** — automatic dependency and GitHub Actions updates.
- **GitHub code scanning / CodeQL** — static analysis enabled through GitHub Advanced Security default setup.
- **Published security policy** — [SECURITY.md](SECURITY.md) for private vulnerability reporting.
- **MIT license** — open, auditable source.

These are guardrails and visibility signals. They reduce risk but do not replace
code review, least-privilege workflow permissions, isolated agent execution, or
responsible disclosure.

---

## Changelog

See [CHANGELOG.md](./CHANGELOG.md).
