# CLAUDE.md

## Role

You are a software engineering agent working on this repository.

Your job: implement, refactor, review, test, and document changes while keeping
the codebase simple, maintainable, testable, and understandable.

The goal is not clever code. The goal is code a new developer can understand
and a team can safely evolve for years.

---

## How to run Claude Code

```bash
claude                           # interactive, default permission mode — confirms risky actions
claude --dangerously-skip-permissions  # fully autonomous; no confirmations (CI / supervised only)
```

Useful flags:
- `--model claude-opus-4-7` — override the model for this session.
- `--continue` — resume the previous session in this directory.
- `--print "task"` — non-interactive single-shot mode (for scripts and CI).

Claude Code reads this file at startup, then auto-loads any `.claude/rules/*.md` whose `paths:`
frontmatter matches the files you open. Skills are lazy-loaded via the routing table below.

**Reference:** [github.com/anthropics/claude-code](https://github.com/anthropics/claude-code)

---

## Session hygiene

Actions, not philosophy. See `docs/ai/CONTEXT_GOVERNANCE.md` for the 40/60/80% thresholds.

| Context state | Action |
|---|---|
| 0–39% | Continue normally. |
| 40–59% | Evaluate: compact before any broad read, large log dump, or multi-file refactor. |
| 60–79% | Run `/compact` before the next step. Default to compaction. |
| 80%+ | Stop. Summarize state, then start a fresh session. |

- **`/compact`** — summarises conversation + tool outputs; preserves the working summary. Use it proactively.
- **`/clear`** — resets conversation history but keeps file cache. Rarely the right choice: it discards the summary without reducing file-context cost. Prefer `/compact` or quit + new session.
- **`claude --continue`** — resumes the previous session (reuses Anthropic's prompt cache). Use when the next task is the same task and the session was recently idle.
- **Auto-compact threshold** — Claude Code does not yet expose a configurable auto-compact trigger (unlike Gemini's `model.compressionThreshold = 0.6`). Use `/compact` manually at the 60% checkpoint.

---

## Slash commands

The kit ships twelve reusable workflow prompts as slash commands under `.claude/commands/`.
Type `/` in Claude Code to autocomplete; pick one and pass the relevant argument.

| Command | Use for | Argument |
|---|---|---|
| `/bug-fix` | Reproduce, root-cause, fix, regression test | issue number |
| `/code-review` | Triage-style review of a branch or diff | branch (optional) |
| `/context-report` | Per-surface token estimate for current session | (none) |
| `/daily-ticket` | Standard issue workflow with skill + subagent routing | issue number |
| `/dependency-update` | Single-package update with license + test + audit | pkg, old, new |
| `/feature-planning` | Plan-only, no code, before a large feature | issue number |
| `/on-call` | Live-incident playbook — triage, mitigate, post-mortem | symptoms |
| `/performance-audit` | Baseline → bottleneck → fix → re-measure | what is slow |
| `/refactor` | Behaviour-preserving refactor with tests green | what to refactor |
| `/run-tests` | Run the suite and report — does not fix failures | (none) |
| `/security-audit` | Find real exploitable issues, triage by severity | scope (optional) |
| `/tech-debt` | Triage-only debt scan across categories | (none) |

## MCP servers

`.mcp.json` at the project root configures Model Context Protocol servers. Empty by default —
add servers per project. See [code.claude.com/docs/en/mcp](https://code.claude.com/docs/en/mcp).

## Plugin marketplace (opt-in)

The kit is also published as a Claude plugin marketplace shipping the 30 skills:
`/plugin marketplace add PetrovC/ai-agent-kit` then `/plugin install ai-agent-kit@ai-agent-kit`.
This is the skills slice only — the install script remains canonical for the full
multi-tool setup (Codex + Gemini + hooks + commands + `docs/ai/`).

## Personal overrides

Create a `CLAUDE.local.md` file in the project root (gitignored) for developer-specific
preferences — local paths, personal aliases, preferred verbosity, machine-specific tools.
It is merged with this file automatically by Claude Code. Do not commit it.

---

## Context strategy

Do not read every file. Read only what is needed, in this order:

1. This file (and `CLAUDE.local.md` if present).
2. The current GitHub issue or task description.
3. `docs/ai/PROJECT.md` when product or domain context is needed.
4. `docs/ai/ARCHITECTURE.md` when the task touches modules, boundaries, or design.
5. `docs/ai/COMMANDS.md` when build/test/lint commands are needed.
6. The relevant skill or rule (see routing below).
7. Source files directly related to the task.

Do not scan the entire repository unless the task explicitly requires it.

Ignore TaskCreate / TaskUpdate / TaskList system-reminders unless the user explicitly asked for an in-conversation task list. The kit tracks progress via GitHub issues, PRs, and `CHANGELOG.md`; in-conversation tasks are redundant noise.

---

## Skill routing

Match the task domain to the skill name — full descriptions live in each skill's `description:` frontmatter.

Backends: `dotnet` skill · `java-kotlin` skill · `python` skill · `node` skill · `go` skill · `rust` skill  
Frontends: `angular` skill · `vue` skill · `svelte` skill · `react` skill · `mobile-rn` skill · `mobile-flutter` skill  
Data/Infra: `database` skill · `infrastructure` skill · `api-design` skill · `graphql` skill  
Quality: `architecture` skill · `testing` skill · `code-review` skill · `security` skill · `dependencies` skill · `github-workflow` skill  
Ops/X-cut: `observability` skill · `messaging` skill · `error-handling` skill · `monorepo` skill · `accessibility` skill · `i18n` skill · `ai-dev` skill · `performance` skill

---

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

---

## Engineering principles

- Prefer simple, explicit, consistent solutions over clever ones.
- Keep changes small and reviewable. One concern per PR.
- Do not over-engineer. Add abstractions only when they remove real duplication or protect a real boundary.
- Respect layer boundaries and dependency direction.
- Avoid unrelated formatting changes.
- Do not add dependencies without justification. **MIT license only.** Avoid library bloat — if it can be done in ~20 lines of native code, do not pull a package. See `dependencies` skill.
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

- [ ] Requested behavior implemented.
- [ ] Change limited to task scope.
- [ ] Tests/build/lint run (or reason documented).
- [ ] New or changed behavior covered by tests. If tests are not added, state explicitly why and what should be tested manually.
- [ ] No unrelated files modified.
- [ ] Risks and assumptions stated.

---

## Final response format

1. **Summary** — what changed and why.
2. **Files changed** — with layer.
3. **Verification** — commands and results.
4. **Risks / assumptions**.
5. **Next step** — only if useful.
