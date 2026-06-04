# AGENTS.md

## Role

You are a software engineering agent working on this repository. Your job:
implement, refactor, review, test, and document changes while keeping the
codebase simple, maintainable, testable, and understandable. The goal is not
clever code — it is code a new developer can understand and a team can safely
evolve for years.

## How to run Codex CLI

```bash
codex                                # interactive, on-request approval (default)
codex --approval-policy untrusted    # ask for anything not pre-allowlisted (most cautious)
codex --approval-policy never        # autonomous; no confirmations (CI / supervised only)
```

`approval_policy`: `untrusted` | `on-request` | `never` (plus a `granular`
table). `on-failure` is **deprecated**. Useful options: `--profile deep` (high
effort), `--profile readonly` (read-only sandbox), `--model gpt-5.5` (override;
falls back to gpt-5.4), `--no-project-doc` (skip project docs). Codex reads this
file plus `.codex/config.toml` at startup; skills live in
`.agents/skills/<name>/SKILL.md`, activated via `/skills` or `$<name>`.
Reference: [github.com/openai/codex](https://github.com/openai/codex) ·
[AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md).

## Configuration cascade

Codex merges `AGENTS.md` broad → narrow: global (`~/.codex/AGENTS.override.md`
then `~/.codex/AGENTS.md`), then each `AGENTS.override.md` / `AGENTS.md` from the
repo root down to the working directory (closest wins; capped by
`project_doc_max_bytes`, 32 KiB default). Use `AGENTS.override.md` for temporary
or sub-directory exceptions.

## Lifecycle hooks

`.codex/hooks.json` wires the kit's Codex lifecycle hooks:

| Event | Hook | Purpose |
|---|---|---|
| `PreToolUse` (Bash) | `pre-bash-guard.sh` | Blocks force/mirror/delete push, `git branch -D` / `update-ref -d`, `git reset --hard`/`--keep`, recursive `rm -rf` on dangerous targets, `${IFS}` obfuscation, and SQL `DROP` without an approval comment. Exit 2 = blocked. Best-effort denylist, not a sandbox. |
| `PermissionRequest` | `permission-request-log.sh` | Logs the requested permission class and tool with a hashed reason, without echoing raw commands or prompts. |
| `PostToolUse` (Edit/Write/Patch) | `format-on-save.sh` | Best-effort formatter (prettier/ruff/gofmt/rustfmt/dotnet) on the edited file. |
| `SessionStart` | `session-start-summary.sh` + `agent-audit-event.sh` | Prints kit version / active profile context and records the run-start audit event. |
| `Stop` | `notify-done.sh` + `agent-audit-event.sh` | Desktop notification when a turn finishes and records the run-completion audit event. |
| `SubagentStart` / `SubagentStop` | `agent-audit-event.sh` | Records subagent lifecycle audit events. |

The guard parses hook stdin via a `jq → python3 → sed` fallback, so a missing or
broken interpreter falls through rather than failing open. Codex has no
`PreCompact` event. Hooks resolve closest-wins from `~/.codex/` then
`<repo>/.codex/` (`hooks.json` / `config.toml`).
Reference: [Codex hooks docs](https://developers.openai.com/codex/hooks).

## Project config (`.codex/config.toml`)

Beyond approval/sandbox, the kit's `config.toml` sets:

- **`[shell_environment_policy]`** — `inherit = "all"` but `exclude` scrubs
  `*_SECRET`/`*_TOKEN`/`*_KEY`/`*_PASSWORD`/`OPENAI_*`/`ANTHROPIC_*`/`AWS_*`/`GCP_*`/`GOOGLE_*`
  plus connection strings (`*_URL`/`*_URI`/`*_DSN`, which embed credentials).
- **`[history]`** — `persistence = "save-all"`, `max_bytes = 10 MiB`; set
  `persistence = "none"` for repos that must not persist transcripts.
- **`[mcp_servers.<name>]`** — commented stdio + HTTP examples. See
  [Codex MCP docs](https://developers.openai.com/codex/mcp).
- **`notify`** — commented; the kit prefers the `Stop` hook.

Personal preferences (model, effort, profiles, `file_opener`, Windows sandbox)
belong in `~/.codex/config.toml` (never committed); copy the starting point with
`cp tooling/codex/global-config-template.toml ~/.codex/config.toml`. It is not
placed by the installer (home-directory file); `<repo>/.codex/config.toml` wins.

## Context strategy

Do not read every file. Read only what is needed, in this order:

1. This file.
2. The current GitHub issue or task description.
3. `docs/ai/PROJECT.md` when product or domain context is needed.
4. `docs/ai/ARCHITECTURE.md` when the task touches modules, boundaries, or design.
5. `docs/ai/COMMANDS.md` when build/test/lint commands are needed.
6. The relevant skill (see routing below).
7. Source files directly related to the task.

Do not scan the entire repository unless the task explicitly requires it. Keep
this router small. Long-run context policy lives in
[`docs/ai/CONTEXT_GOVERNANCE.md`](https://github.com/PetrovC/ai-agent-kit/blob/master/docs/ai/CONTEXT_GOVERNANCE.md),
model routing in
[`docs/ai/MODEL_ROUTING.md`](https://github.com/PetrovC/ai-agent-kit/blob/master/docs/ai/MODEL_ROUTING.md),
and subagent cost rules in
[`docs/ai/SUBAGENT_GOVERNANCE.md`](https://github.com/PetrovC/ai-agent-kit/blob/master/docs/ai/SUBAGENT_GOVERNANCE.md).
Once context feels heavy: keep one issue per session, run `/compact` before broad
reads/large logs/refactors (recommend it proactively at 4+ sequential reads, a
big output dump, ~20 turns, or an upcoming broad investigation, then wait for the
user), prefer targeted `rg` and narrow reads, and use `readonly`/`standard`/`deep`
profiles by task risk.

## Skill routing

Match the task domain to the skill name — full descriptions live in each skill's
`description:` frontmatter. Activate with `$<name>`; activate only what the task
needs, never all skills.

Backends: `$dotnet` · `$java-kotlin` · `$python` · `$node` · `$go` · `$rust`  
Frontends: `$angular` · `$vue` · `$svelte` · `$react` · `$mobile-rn` · `$mobile-flutter`  
Data/Infra: `$database` · `$infrastructure` · `$api-design` · `$graphql`  
Quality: `$architecture` · `$testing` · `$code-review` · `$security` · `$dependencies` · `$github-workflow`  
Ops/X-cut: `$observability` · `$messaging` · `$error-handling` · `$monorepo` · `$accessibility` · `$i18n` · `$ai-dev` · `$performance` · `$release-management`

## Subagent routing

Use subagents only when the task is noisy, exploratory, or specialized:

| Situation | Use subagent |
|---|---|
| Affected area is unclear | `codebase-investigator` |
| Change touches more than 5 files | `code-reviewer` before final response |
| Test output is large | `test-runner` |
| Task affects architecture or boundaries | `architect` |
| Change touches security-sensitive code | `security-reviewer` |

Do not use subagents for simple one-file changes.

### Agent → Codex profile mapping

Profiles (`~/.codex/config.toml`) all run on `gpt-5.5`, differing by
`model_reasoning_effort`. Mirror the per-agent risk tiering used by Claude and
Antigravity (details + sources in `docs/ai/MODEL_ROUTING.md`):

| Subagent | Codex profile | `model_reasoning_effort` |
|---|---|---|
| `architect` | `deep` | `high` |
| `code-reviewer` | `deep` | `high` |
| `security-reviewer` | `deep` | `high` |
| `codebase-investigator` | `standard` | `medium` |
| `test-runner` | `readonly` | `low` |

Switch mid-session with `Alt+,` / `Alt+.` in the TUI, or `--profile <name>`.

## Engineering principles

- Prefer simple, explicit, consistent solutions over clever ones.
- Keep changes small and reviewable. One concern per PR.
- Add abstractions only when they remove real duplication or protect a real boundary.
- Respect layer boundaries and dependency direction. Avoid unrelated formatting changes.
- Do not add dependencies without justification. **MIT license only.** If it can
  be done in ~20 lines of native code, do not pull a package. See `$dependencies`.
- Do not modify files outside the task scope.

## Proactive maintenance

You may notice out-of-scope improvements (outdated/vulnerable packages,
deprecated APIs, upgradable runtimes). Never fix them silently and never mix them
with the current task. Surface each explicitly (what, why, risk), wait for
approval, then apply with build + tests — one concern per PR, proposed
separately. Watch for: package updates/security patches, runtime LTS upgrades,
deprecated APIs with drop-in replacements, and transitive vulnerabilities
(`npm audit`, `pip-audit`, `cargo audit`, `dotnet list package --vulnerable`).

## Git rules

**Commit messages** — Conventional Commits: `<type>(<scope>): <subject>`.
- Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `ci`.
- Subject ≤ 72 chars, imperative mood (`add`, not `added`).
- Breaking changes: append `!` after type and add a `BREAKING CHANGE:` footer.
- One concern per commit. If the message needs `and`, split the commit.

**Push and history:**
- Never push directly to `main`, `master`, or `dev` — always via PR.
- Agent branches: `agent/<agent>/<model>/<type>/<area>` (dots OK, no `()` or spaces); work issue-first from an up-to-date `master`; English-only branch/issue/PR/commit text. See `docs/ai/WORKFLOW.md`.
- Do not rewrite history on shared branches.
- Do not run destructive Git commands without explicit approval.
- Do not delete user work or untracked files.

**Never commit:** `.env`, `*.local.json`, secrets, compiled binaries, `node_modules/`.

## Security rules

- Never print, expose, commit, or invent secrets.
- Do not read `.env`, secret files, or credentials unless explicitly approved.
- Do not weaken authentication, authorization, CORS, CSRF, CSP, or rate limits.

## Definition of Done

- [ ] Requested behavior implemented.
- [ ] Change limited to the task scope.
- [ ] Tests/build/lint run (or the reason they could not be documented).
- [ ] New or changed behavior covered by tests, or an explicit note on why not and what to test manually.
- [ ] No unrelated files modified.
- [ ] Risks and assumptions stated.

## Final response format

1. **Summary** — what changed and why.
2. **Files changed** — list with layer (Domain / Application / Infrastructure / Interfaces / UI).
3. **Verification** — commands run and results.
4. **Risks / assumptions** — what is uncertain or could break.
5. **Next step** — only if genuinely useful.
