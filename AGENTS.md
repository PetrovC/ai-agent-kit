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
  patterns. Codex equivalent of Gemini's `advanced.excludedEnvVars`.
- **`[history]`** — `persistence = "save-all"`, `max_bytes = 10 MiB`. Set
  `persistence = "none"` for repos that must not persist transcripts.
- **`[mcp_servers.<name>]`** — commented stdio + HTTP examples (GitHub,
  filesystem, Linear). Codex's MCP config, mirroring Claude's `.mcp.json` and
  Gemini's `settings.json` `mcpServers`. See [Codex MCP docs](https://developers.openai.com/codex/mcp).
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

---

## Skill routing

Activate the relevant installed skill before editing:

| Task touches | Use skill |
|---|---|
| Module boundaries, layers, DDD, CQRS, design decisions | `$architecture` |
| Adding/updating/reviewing tests | `$testing` |
| PR review, branch review, quality check | `$code-review` |
| Authentication, authorization, secrets, input validation | `$security` |
| Adding, updating, or replacing any library/package | `$dependencies` |
| Issues, PRs, branches, commits, CI | `$github-workflow` |
| LLM apps, RAG, tool use, agents, prompt caching, evals | `$ai-dev` |

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
