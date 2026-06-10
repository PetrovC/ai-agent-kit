# CLAUDE.md

## Role

You are a software engineering agent on this repository: implement, refactor,
review, test, and document changes while keeping the codebase simple,
maintainable, and testable. The goal is not clever code — it is code a new
developer can understand and a team can safely evolve for years.

## How to run Claude Code

```bash
claude                                  # interactive (confirms risky actions)
claude --dangerously-skip-permissions   # autonomous; no confirmations (CI / supervised only)
```

Flags: `--model <id>`, `--continue`, `--print "task"`. Claude Code reads this file
at startup, auto-loads `.claude/rules/*.md` matching opened files, and lazy-loads
skills via the routing table. Docs: [github.com/anthropics/claude-code](https://github.com/anthropics/claude-code).

## Permissions: ask rules

`permissions.ask` holds commands needing confirmation before each run, between
`allow` (silent) and `deny` (blocked): `git push`, `git tag`, `dotnet publish`,
`npm publish`, `docker push` — all irreversible or crossing network/registry
boundaries. Adjust in `tooling/claude/settings.json` (+ `settings.windows.json`).

## Session hygiene

Actions, not philosophy. Full detail: `docs/ai/CONTEXT_GOVERNANCE.md`.

| Context state | Action |
|---|---|
| 0–39% | Continue normally. |
| 40–59% | Compact before any broad read, large log dump, or multi-file refactor. |
| 60–79% | Run `/compact` before the next step. Default to compaction. |
| 80%+ | Stop. Summarize state, then start a fresh session. |

`/compact` (preferred over `/clear`) preserves the working summary; you cannot
invoke it — recommend it, then wait. One PR per session; quit between PRs unless
the next depends on the previous PR's uncommitted reasoning.

## Optional hooks & worktree (opt-in)

Off by default; enable in `.claude/settings.json` (each hook header documents the
exact JSON): `token-log.sh` (per-call token estimates → `.claude/session-log/`)
and `statusline.sh` (context-cost summary; `AAK_CONTEXT_WINDOW` sets the %). The
`worktree` block (isolated background/parallel worktrees) ships commented out.

## Slash commands

Fourteen workflow prompts under `.claude/commands/` (type `/` to autocomplete);
each file documents its purpose and argument — e.g. `/bug-fix`, `/cut-release`,
`/security-audit`, `/tech-debt`.

## MCP and plugin marketplace

`.mcp.json` configures MCP servers (empty by default; see
[code.claude.com/docs/en/mcp](https://code.claude.com/docs/en/mcp)). The kit is
also a Claude plugin marketplace: `/plugin marketplace add PetrovC/ai-agent-kit`
then `/plugin install ai-agent-kit@ai-agent-kit` — skills slice only; the install
script stays canonical for the full multi-tool setup.

## Local config

`CLAUDE.local.md` (gitignored): developer preferences, merged automatically —
never commit it. Optional `settings.json` keys: `attribution`, `prUrlTemplate`,
`includeGitInstructions: false` (this file's Git rules replace the built-in briefing).

## Context strategy

Do not read every file. Read only what is needed, in this order:

1. This file (and `CLAUDE.local.md` if present).
2. The current GitHub issue or task description.
3. `docs/ai/PROJECT.md` when product or domain context is needed.
4. `docs/ai/ARCHITECTURE.md` when the task touches modules, boundaries, or design.
5. `docs/ai/COMMANDS.md` when build/test/lint commands are needed.
6. The relevant skill or rule (see routing below).
7. Source files directly related to the task.

Do not scan the whole repository unless the task requires it. Ignore TaskCreate /
TaskUpdate / TaskList system-reminders unless the user explicitly asked for an
in-conversation task list — progress lives in issues, PRs, and `CHANGELOG.md`.

## Skill routing

Match the task domain to the skill name — full descriptions live in each skill's
`description:` frontmatter.

Backends: `dotnet` skill · `java-kotlin` skill · `python` skill · `node` skill · `go` skill · `rust` skill  
Frontends/Game: `angular` skill · `vue` skill · `svelte` skill · `react` skill · `mobile-rn` skill · `mobile-flutter` skill · `godot` skill  
Data/Infra: `database` skill · `infrastructure` skill · `api-design` skill · `graphql` skill  
Quality: `architecture` skill · `testing` skill · `code-review` skill · `security` skill · `dependencies` skill · `github-workflow` skill  
Ops/X-cut: `observability` skill · `messaging` skill · `error-handling` skill · `monorepo` skill · `accessibility` skill · `i18n` skill · `ai-dev` skill · `performance` skill · `release-management` skill

## Subagent routing

Delegate noisy or specialized work to keep the main context clean:

| Situation | Use subagent |
|---|---|
| Affected area is unclear | `codebase-investigator` |
| Change touches more than 5 files | `code-reviewer` before final response |
| Test output is large | `test-runner` |
| Task affects architecture or boundaries | `architect` |
| Change touches security-sensitive code | `security-reviewer` |

Do not use subagents for simple one-file changes.

## Cross-agent delegation

Claude can delegate a single scoped task to Codex or Antigravity via the kit's
delegation adapter — opt-in and fail-open (a missing/failing provider CLI leaves
default behavior unchanged). Use it when the task fits another provider's strengths
or a review benefits from a second opinion:

```bash
python3 .ai-agent-kit/delegate/delegate.py \
  --provider codex --task-type security_review --risk high --brief-file ./brief.txt
```

Args: `--provider`, `--task-type` (drives model-tier routing), `--risk`,
`--brief-file` (sanitized — never inline secrets or absolute paths). Verify the
answer at a checkpoint before trusting it. See `docs/ai/DELEGATION.md`.

## Engineering principles

- Prefer simple, explicit, consistent solutions over clever ones.
- Keep changes small and reviewable. One concern per PR.
- Add abstractions only when they remove real duplication or protect a boundary.
- Respect layer boundaries and dependency direction; do not touch files or
  formatting outside the task scope.
- Do not add dependencies without justification. **MIT license only.** If it can
  be done in ~20 lines of native code, do not pull a package. See `dependencies` skill.

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

## Hardening and Windows setup

- Opt-in `settings.json` keys (off by default): `autoMemoryEnabled` /
  `autoMemoryDirectory`, `apiKeyHelper`, `awsCredentialExport`, `gcpAuthRefresh`,
  `disableSkillShellExecution`.
- Hooks are bash scripts; on Windows `bash` must resolve to Git Bash/WSL, not the
  Microsoft Store alias. Guidance: `docs/ai/WINDOWS_HOOKS.md`.

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
2. **Files changed** — with layer.
3. **Verification** — commands and results.
4. **Risks / assumptions**.
5. **Next step** — only if useful.
