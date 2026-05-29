# AGENTS.md

## Role

You are a software engineering agent working on this repository.

Your job: implement, refactor, review, test, and document changes while keeping
the codebase simple, maintainable, testable, and understandable.

The goal is not clever code. The goal is code a new developer can understand
and a team can safely evolve for years.

---

## How to run Codex CLI

```bash
codex                              # interactive, on-request approval (default)
codex --approval-policy untrusted     # ask for anything not pre-allowlisted (most cautious)
codex --approval-policy never         # fully autonomous; no confirmations (CI / supervised only)
```

Valid `approval_policy` values: `untrusted` | `on-request` | `never` (plus a
`granular` table for fine-grained control). `on-failure` is **deprecated** —
use `on-request` for interactive runs or `never` for non-interactive runs.

Useful options:
- `--profile deep` — switch to the `deep` reasoning profile (high effort, slower, more thorough).
- `--profile readonly` — read-only sandbox; safe for exploration without any writes.
- `--model gpt-5.5` — override the model for this session (current recommended; falls back to gpt-5.4).
- `--no-project-doc` — skip loading project docs (faster for quick one-off tasks).

Codex reads this file at startup along with `.codex/config.toml` for project-level settings.
Skills live in `.agents/skills/<name>/SKILL.md` and are activated via `/skills` or by typing `$` in the prompt.

## Configuration cascade

Codex merges AGENTS.md files from broad to narrow:

1. `~/.codex/AGENTS.override.md` then `~/.codex/AGENTS.md` (global).
2. Each `AGENTS.override.md` / `AGENTS.md` walking from the git repo root down to the working directory.
3. Files closer to the working directory take precedence; total merged content is capped by `project_doc_max_bytes` (32 KiB by default).

Use `AGENTS.override.md` for temporary or sub-directory exceptions without disturbing the main file.

**Reference:** [github.com/openai/codex](https://github.com/openai/codex) · [Codex AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md) · GitHub Action: [github.com/openai/codex-action](https://github.com/openai/codex-action)

---

## Lifecycle hooks

This kit ships `.codex/hooks.json` wiring three safety/QoL hooks (mirrors the
Claude Code setup so behaviour is consistent across tools):

| Event | Hook | Purpose |
|---|---|---|
| `PreToolUse` (Bash) | `pre-bash-guard.sh` | Blocks force/mirror/delete push (incl. `+refspec`), `git branch -D` / `update-ref -d`, `git reset --hard`/`--keep`, recursive `rm -rf` on absolute/home/parent/cwd/glob/variable targets, `${IFS}` obfuscation, and SQL `DROP` without an approval comment. Exit 2 = blocked. **Best-effort denylist, not a sandbox** — see the script header. |
| `PostToolUse` (Edit/Write/Patch) | `format-on-save.sh` | Best-effort formatter (prettier/ruff/gofmt/rustfmt/dotnet) on the edited file. |
| `Stop` | `notify-done.sh` | Desktop notification when a turn finishes. |

The guard parses the hook stdin JSON via a `jq → python3 → sed` fallback chain:
a missing or broken interpreter (e.g. the Windows python3 stub) yields empty
stdout and falls through to the next parser, so it never fails open. Codex has
no `PreCompact` event, so the Claude `session-summary` hook has no Codex
equivalent.

Hooks resolve from (closest wins): `~/.codex/hooks.json`, `~/.codex/config.toml`,
`<repo>/.codex/hooks.json`, `<repo>/.codex/config.toml`.

**Reference:** [Codex hooks docs](https://developers.openai.com/codex/hooks)

---

## Project config (`.codex/config.toml`)

Beyond approval/sandbox, the kit's `config.toml` sets:

- **`[shell_environment_policy]`** — `inherit = "all"` but `exclude` scrubs
  `*_SECRET`/`*_TOKEN`/`*_KEY`/`*_PASSWORD`/`OPENAI_*`/`ANTHROPIC_*`/`AWS_*`/`GCP_*`/`GOOGLE_*`
  **plus** connection strings (`*_URL`/`*_URI`/`*_DSN`) — `DATABASE_URL`-class
  values routinely embed `user:password@host` and matched none of the older
  patterns. Codex equivalent of Antigravity's
  `security.environmentVariableRedaction.blocked`.
- **`[history]`** — `persistence = "save-all"`, `max_bytes = 10 MiB`. Set
  `persistence = "none"` for repos that must not persist transcripts.
- **`[mcp_servers.<name>]`** — commented stdio + HTTP examples (GitHub,
  filesystem, Linear). Codex's MCP config, mirroring Claude's `.mcp.json` and
  Antigravity's `settings.json` `mcpServers`. See [Codex MCP docs](https://developers.openai.com/codex/mcp).
- **`notify`** — commented; the kit prefers the `Stop` hook form. Uncomment to
  use the config.toml notification mechanism instead.

---

## Personal config (`~/.codex/config.toml`)

Project `.codex/config.toml` (above) holds **shared** settings. Your **personal**
preferences — model, reasoning effort, profiles (`readonly`/`standard`/`deep`/
`review`), `file_opener`, Windows sandbox — belong in `~/.codex/config.toml`,
which is never committed. The kit ships a ready-to-copy starting point:

```bash
cp tooling/codex/global-config-template.toml ~/.codex/config.toml   # then edit
```

It is intentionally **not** placed by the install script (it is a per-user
home-directory file, not a project file). Closest-wins resolution still applies:
`~/.codex/config.toml` is overridden by `<repo>/.codex/config.toml`.

---

## Context strategy

Do not read every file. Read only what is needed, in this order:

1. This file.
2. The current GitHub issue or task description.
3. `docs/ai/PROJECT.md` when product or domain context is needed.
4. `docs/ai/ARCHITECTURE.md` when the task touches modules, boundaries, or design.
5. `docs/ai/COMMANDS.md` when build/test/lint commands are needed.
6. The relevant skill (see routing below).
7. Source files directly related to the task.

Do not scan the entire repository unless the task explicitly requires it.
Keep this router small. Long-run context policy lives in
[`docs/ai/CONTEXT_GOVERNANCE.md`](https://github.com/PetrovC/ai-agent-kit/blob/master/docs/ai/CONTEXT_GOVERNANCE.md),
and model routing details live in
[`docs/ai/MODEL_ROUTING.md`](https://github.com/PetrovC/ai-agent-kit/blob/master/docs/ai/MODEL_ROUTING.md).
Subagent cost rules live in
[`docs/ai/SUBAGENT_GOVERNANCE.md`](https://github.com/PetrovC/ai-agent-kit/blob/master/docs/ai/SUBAGENT_GOVERNANCE.md).

### Codex long-run mode

Use this checklist when a Codex session starts to feel context-heavy:

- Keep one GitHub issue per session by default; before switching issues, summarize and end the old context.
- Run `/compact` before broad reads, large logs, or refactors once context feels heavy. Recommend it proactively when you observe 4+ sequential reads, a large tool-output dump, ~20 turns, or an upcoming broad investigation — surface the recommendation before the heavy step, then wait for the user to type the command.
- Do not paste `AGENTS.md` into chat; Codex already loads it at startup.
- Prefer targeted `rg`, GitHub issue/PR reads, and narrow file reads over broad scans.
- Use `readonly` for audit/exploration, `standard` for daily implementation, and `deep` only for design/review/security decisions.
- Use subagents only when they reduce main-context cost; see `docs/ai/SUBAGENT_GOVERNANCE.md`.

---

## Skill routing

Match the task domain to the skill name — full descriptions live in each skill's `description:` frontmatter. Activate with `$<name>`.

Backends: `$dotnet` · `$java-kotlin` · `$python` · `$node` · `$go` · `$rust`  
Frontends: `$angular` · `$vue` · `$svelte` · `$react` · `$mobile-rn` · `$mobile-flutter`  
Data/Infra: `$database` · `$infrastructure` · `$api-design` · `$graphql`  
Quality: `$architecture` · `$testing` · `$code-review` · `$security` · `$dependencies` · `$github-workflow`  
Ops/X-cut: `$observability` · `$messaging` · `$error-handling` · `$monorepo` · `$accessibility` · `$i18n` · `$ai-dev` · `$performance`

Activate only the skills relevant to the current task.
Do not activate all skills by default.

---

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

Codex CLI 2026 routes work through profiles defined in `~/.codex/config.toml`
(`readonly` / `standard` / `deep` / `review`). All profiles run on `gpt-5.5`;
they differ by `model_reasoning_effort`. Use the following mapping so Codex
matches the per-agent risk tiering used by Claude (Opus/Sonnet/Haiku) and
Antigravity (Pro/Flash):

| Subagent | Codex profile | `model_reasoning_effort` | Why |
|---|---|---|---|
| `architect` | `deep` | `high` | Decision-bearing design assessment. |
| `code-reviewer` | `deep` | `high` | High-stakes review of multi-file changes. |
| `security-reviewer` | `deep` | `high` | Real exploitable vulnerabilities, not theoretical risk. |
| `codebase-investigator` | `standard` | `medium` | Narrow lookups; deterministic search first per ADR-017. |
| `test-runner` | `readonly` | `low` | Mechanical: filtered run + concise report. |

Switch profile mid-session with `Alt+,` (lower) / `Alt+.` (raise) in the TUI,
or pass `--profile <name>` at launch.

Verified GA model as of May 2026 (OpenAI): `gpt-5.5` with reasoning effort
levels `none` / `low` / `medium` (default) / `high` / `xhigh`. See
<https://developers.openai.com/codex/models>.

---

## Engineering principles

- Prefer simple, explicit, consistent solutions over clever ones.
- Keep changes small and reviewable. One concern per PR.
- Do not over-engineer. Add abstractions only when they remove real duplication or protect a real boundary.
- Respect layer boundaries and dependency direction at all times.
- Avoid unrelated formatting changes.
- Do not add dependencies without justification. **MIT license only.** Avoid library bloat — if it can be done in ~20 lines of native code, do not pull a package. See `$dependencies`.
- Do not modify files outside the task scope.

---

## Proactive maintenance

While working on a task, you may notice things outside the current scope that should be improved (outdated packages, deprecated APIs, runtime version upgrades).

Rules:
- **Never apply maintenance changes silently.** Always surface them first.
- **Do not mix** maintenance changes with the current task — one concern per PR.
- **Propose** each item explicitly: what you found, why it matters, and what the risk is.
- **Wait for explicit approval** before touching anything outside the task scope.
- When approved: apply the change, run builds and tests, and report what changed.

Things to surface proactively (never fix without asking):
- Packages with available updates, especially security patches.
- Project runtime or SDK version upgradeable to a stable LTS release.
- Deprecated API calls with drop-in replacements.
- Transitive vulnerabilities (`dotnet list package --vulnerable`, `npm audit`, `pip-audit`, `cargo audit`, etc.).

Example proposal:
> I noticed `SomePackage` is on v3.1.0; v4.2.1 is available (patches CVE-XXXX-YYYY).
> Shall I update it? I will run build + tests after the change.

Always apply the "one concern per PR" rule — propose each maintenance item separately.

---

## Git rules

**Commit messages** — Conventional Commits: `<type>(<scope>): <subject>`.
- Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `ci`.
- Subject ≤ 72 chars, imperative mood (`add`, not `added`).
- Breaking changes: append `!` after type and add a `BREAKING CHANGE:` footer.
- One concern per commit. If the message needs `and`, split the commit.

**Push and history:**
- Never push directly to `main`, `master`, or `dev` — always via PR.
- Do not rewrite history on shared branches.
- Do not run destructive Git commands without explicit approval.
- Do not delete user work or untracked files.

**Never commit:** `.env`, `*.local.json`, secrets, compiled binaries, `node_modules/`.

---

## Security rules

- Never print, expose, commit, or invent secrets.
- Do not read `.env`, secret files, or credentials unless explicitly approved.
- Do not weaken authentication, authorization, CORS, CSRF, CSP, or rate limits.

---

## Definition of Done

A task is done only when:

- [ ] The requested behavior is implemented.
- [ ] The change is limited to the task scope.
- [ ] Relevant tests/build/lint were run (or the reason they could not be run is documented).
- [ ] New or changed behavior covered by tests. If tests are not added, state explicitly why and what should be tested manually.
- [ ] No unrelated files were modified.
- [ ] Risks and assumptions are clearly stated.

---

## Final response format

Always finish with:

1. **Summary** — what changed and why.
2. **Files changed** — list with layer (Domain / Application / Infrastructure / Interfaces / UI).
3. **Verification** — commands run and results.
4. **Risks / assumptions** — what is uncertain or could break.
5. **Next step** — only if genuinely useful.

Keep it concise and factual.
