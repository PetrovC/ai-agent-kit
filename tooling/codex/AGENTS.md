# AGENTS.md

## Role

You are a software engineering agent on this repository: implement, refactor,
review, test, and document changes while keeping the codebase simple,
maintainable, and testable. The goal is not clever code — it is code a new
developer can understand and a team can safely evolve for years.

## How to run Codex CLI

```bash
codex                                # interactive, on-request approval (default)
codex --approval-policy untrusted    # ask for anything not pre-allowlisted (most cautious)
codex --approval-policy never        # autonomous; no confirmations (CI / supervised only)
```

`approval_policy`: `untrusted` | `on-request` | `never` (plus a `granular` table;
`on-failure` is **deprecated**). Useful: `--profile deep` (high effort),
`--profile readonly` (read-only sandbox), `--model gpt-5.5` (falls back to
gpt-5.4). Codex reads this file plus `.codex/config.toml` at startup; skills live
in `.agents/skills/<name>/SKILL.md`, activated via `/skills` or `$<name>`.
Reference: [github.com/openai/codex](https://github.com/openai/codex).

## Configuration cascade

Codex merges `AGENTS.md` broad → narrow: global (`~/.codex/AGENTS.override.md`
then `~/.codex/AGENTS.md`), then each `AGENTS.override.md` / `AGENTS.md` from repo
root down to the working directory (closest wins; capped by `project_doc_max_bytes`,
32 KiB). Use `AGENTS.override.md` for temporary or sub-directory exceptions.

## Lifecycle hooks

`.codex/hooks.json` wires the kit's Codex lifecycle hooks (parse via
`jq → python3 → sed` fallback, so a broken interpreter falls through rather than
failing open; closest-wins from `~/.codex/` then `<repo>/.codex/`):

| Event | Hook | Purpose |
|---|---|---|
| `PreToolUse` (Bash) | `pre-bash-guard.sh` | Blocks force/mirror/delete push, `git branch -D` / `update-ref -d`, `git reset --hard`, recursive `rm -rf` on dangerous targets, `${IFS}` obfuscation, SQL `DROP` without approval. Exit 2 = blocked. Denylist, not a sandbox. |
| `PermissionRequest` | `permission-request-log.sh` | Logs permission class + tool with a hashed reason; no raw commands/prompts. |
| `PostToolUse` (Edit/Write) | `format-on-save.sh` | Best-effort formatter (prettier/ruff/gofmt/rustfmt/dotnet). |
| SessionStart | `session-start-summary.sh` | Prints kit version and active profile. |
| Stop | `notify-done.sh` | Desktop notification when a turn finishes. |

Codex has no `PreCompact` event. Reference: [Codex hooks docs](https://developers.openai.com/codex/hooks).

## Project config (`.codex/config.toml`)

Beyond approval/sandbox, the kit's `config.toml` sets:
- **`[shell_environment_policy]`** — `inherit = "all"` but `exclude` scrubs
  `*_SECRET`/`*_TOKEN`/`*_KEY`/`*_PASSWORD`/`OPENAI_*`/`ANTHROPIC_*`/`AWS_*`/`GCP_*`/`GOOGLE_*`
  plus connection strings (`*_URL`/`*_URI`/`*_DSN`).
- **`[history]`** — `persistence = "save-all"`, `max_bytes = 10 MiB`; set `none`
  for repos that must not persist transcripts.
- **`[mcp_servers.<name>]`** — commented stdio + HTTP examples.

Personal preferences (model, effort, profiles, Windows sandbox) belong in
`~/.codex/config.toml` (never committed; `<repo>/.codex/config.toml` wins). Copy
the starting point from `tooling/codex/global-config-template.toml`.

## Context strategy

Do not read every file. Read only what is needed, in this order:

1. This file.
2. The current GitHub issue or task description.
3. `docs/ai/PROJECT.md` when product or domain context is needed.
4. `docs/ai/ARCHITECTURE.md` when the task touches modules, boundaries, or design.
5. `docs/ai/COMMANDS.md` when build/test/lint commands are needed.
6. The relevant skill (see routing below).
7. Source files directly related to the task.

Do not scan the whole repository unless the task requires it. Long-run context
policy lives in `docs/ai/CONTEXT_GOVERNANCE.md`, model routing in
`docs/ai/MODEL_ROUTING.md`, subagent cost rules in `docs/ai/SUBAGENT_GOVERNANCE.md`.
Keep one issue per session; run `/compact` before broad reads/large logs/refactors;
prefer targeted `rg` and narrow reads; pick `readonly`/`standard`/`deep` by risk.

## Skill routing

Match the task domain to the skill name — full descriptions live in each skill's
`description:` frontmatter. Activate with `$<name>`; only what the task needs.

Backends: `$dotnet` · `$java-kotlin` · `$python` · `$node` · `$go` · `$rust`  
Frontends/Game: `$angular` · `$vue` · `$svelte` · `$react` · `$mobile-rn` · `$mobile-flutter` · `$godot`  
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

Do not use subagents for simple one-file changes. The 5 agents are declared as
native `[agents.<name>]` tables in `.codex/config.toml` (all on `gpt-5.5`,
differing by `model_reasoning_effort`): `architect` / `code-reviewer` /
`security-reviewer` = `deep`/`high`; `codebase-investigator` = `standard`/`medium`;
`test-runner` = `readonly`/`low`. Switch with `--profile <name>` or `Alt+,`/`Alt+.`.
Details in `docs/ai/MODEL_ROUTING.md`.

## Cross-agent delegation

Codex can delegate a single scoped task to Claude or Antigravity via the kit's
delegation adapter — opt-in and fail-open (a missing/failing provider CLI leaves
default behavior unchanged). Use it when the task fits another provider's strengths
or a review benefits from a second opinion:

```bash
python3 .ai-agent-kit/delegate/delegate.py \
  --provider claude --task-type security_review --risk high --brief-file ./brief.txt
```

Args: `--provider` (`claude`|`codex`|`antigravity`), `--task-type` (drives
model-tier routing), `--risk`, `--brief-file` (sanitized — never inline secrets or
absolute paths). Verify the answer at a checkpoint before trusting it. See
`docs/ai/DELEGATION.md`.

## Engineering principles

- Prefer simple, explicit, consistent solutions over clever ones.
- Keep changes small and reviewable. One concern per PR.
- Add abstractions only when they remove real duplication or protect a boundary.
- Respect layer boundaries and dependency direction; do not touch files or
  formatting outside the task scope.
- Do not add dependencies without justification. **MIT license only.** If it can
  be done in ~20 lines of native code, do not pull a package. See `$dependencies`.

## Proactive maintenance

You may notice out-of-scope improvements (outdated/vulnerable packages, deprecated
APIs, upgradable runtimes). Never fix them silently or mix them with the current
task — surface each (what, why, risk), get approval, then apply with build + tests
(one concern per PR). Watch `npm audit`, `pip-audit`, `cargo audit`, `dotnet list package --vulnerable`.

## Git rules

**Commit messages** — Conventional Commits: `<type>(<scope>): <subject>`.
- Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `ci`.
- Subject ≤ 72 chars, imperative mood (`add`, not `added`).
- Breaking changes: append `!` after type and add a `BREAKING CHANGE:` footer.
- One concern per commit. If the message needs `and`, split the commit.

**Push and history:**
- Never push directly to `main`, `master`, or `dev` — always via PR.
- Agent branches: `agent/<agent>/<model>/<type>/<area>` (dots OK, no `()` or
  spaces); work issue-first from an up-to-date `master`; English-only text. See
  `docs/ai/WORKFLOW.md`.
- Do not rewrite history on shared branches.
- Do not run destructive Git commands without explicit approval.
- Do not delete user work or untracked files.

**Never commit:** `.env`, `*.local.json`, secrets, compiled binaries, `node_modules/`.

## Security rules

- Never print, expose, commit, or invent secrets.
- Do not read `.env`, secret files, or credentials unless explicitly approved.
- Do not weaken authentication, authorization, CORS, CSRF, CSP, or rate limits.

## Reverse validation

For non-trivial tasks, do not stop at the first plausible solution. Work backwards
from the solution to the original problem: verify it satisfies the actual need,
constraints, edge cases, and maintainability. If gaps appear, adjust before
presenting. Concise for small tasks, explicit for risky business logic,
architecture, security, data, or workflow. See `docs/ai/REVERSE_VALIDATION.md`.

## Definition of Done

- [ ] Requested behavior implemented.
- [ ] Change limited to task scope.
- [ ] Tests/build/lint run (or reason documented).
- [ ] New or changed behavior covered by tests, or a note on why not.
- [ ] No unrelated files modified.
- [ ] Risks and assumptions stated.

## Final response format

1. **Summary** — what changed and why.
2. **Files changed** — with layer (Domain / Application / Infrastructure / Interfaces / UI).
3. **Verification** — commands and results.
4. **Risks / assumptions**.
5. **Next step** — only if useful.
