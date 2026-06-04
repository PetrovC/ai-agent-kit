# CLAUDE.md

## Role

You are a software engineering agent working on this repository. Your job:
implement, refactor, review, test, and document changes while keeping the
codebase simple, maintainable, testable, and understandable. The goal is not
clever code â€” it is code a new developer can understand and a team can safely
evolve for years.

## How to run Claude Code

```bash
claude                                  # interactive (confirms risky actions)
claude --dangerously-skip-permissions   # autonomous; no confirmations (CI / supervised only)
```

Flags: `--model <id>` (override model for the session), `--continue` (resume the
previous session), `--print "task"` (non-interactive single-shot). Claude Code
reads this file at startup, auto-loads any `.claude/rules/*.md` whose `paths:`
match the files you open, and lazy-loads skills via the routing table below.
Reference: [github.com/anthropics/claude-code](https://github.com/anthropics/claude-code).

## Permissions: ask rules

The `permissions.ask` list holds commands that require explicit interactive confirmation before each run. This list sits between `allow` (silently permitted) and `deny` (hard-blocked).

Commands currently configured under `ask`:
- `git push` (all remotes)
- `git tag` (all forms)
- `dotnet publish`
- `npm publish`
- `docker push`

**Rationale:** These operations are irreversible or cross network/registry boundaries (e.g., pushing code or container images to remotes, creating release tags, or publishing build artifacts), and thus warrant confirmation. To adjust these rules, edit `tooling/claude/settings.json` and its Windows variant `tooling/claude/settings.windows.json`.

## Session hygiene

Actions, not philosophy. Full detail: `docs/ai/CONTEXT_GOVERNANCE.md`.

| Context state | Action |
|---|---|
| 0â€“39% | Continue normally. |
| 40â€“59% | Compact before any broad read, large log dump, or multi-file refactor. |
| 60â€“79% | Run `/compact` before the next step. Default to compaction. |
| 80%+ | Stop. Summarize state, then start a fresh session. |

- `/compact` summarises conversation + tool output and preserves the working
  summary; prefer it over `/clear`. You cannot invoke it â€” recommend it, then
  wait for the user.
- Recommend `/compact` **before** a heavy step: 4+ sequential reads, a large
  log/diff/test dump just landed, ~20+ turns, or a broad multi-file refactor.
- One PR per session; quit between PRs. Stay in-session only when the next PR
  depends on the previous PR's uncommitted reasoning â€” once merged, it is in git.

## Slash commands

Fourteen workflow prompts under `.claude/commands/` (type `/` to autocomplete);
each command file documents its purpose and argument:
`/bug-fix`, `/code-review`, `/context-report`, `/cut-release`, `/daily-ticket`,
`/dependency-update`, `/feature-planning`, `/on-call`, `/performance-audit`,
`/refactor`, `/release-check`, `/run-tests`, `/security-audit`, `/tech-debt`.

## MCP servers

`.mcp.json` at the project root configures MCP servers. Empty by default â€” add
per project. See [code.claude.com/docs/en/mcp](https://code.claude.com/docs/en/mcp).

## Plugin marketplace (opt-in)

Also published as a Claude plugin marketplace shipping the 31 skills:
`/plugin marketplace add PetrovC/ai-agent-kit` then
`/plugin install ai-agent-kit@ai-agent-kit`. Skills slice only â€” the install
script remains canonical for the full multi-tool setup.

## Personal overrides

Create `CLAUDE.local.md` (gitignored) for developer-specific preferences â€” local
paths, aliases, verbosity, machine-specific tools. Merged automatically; never
commit it.

## PR and commit settings

Optional `settings.json` (or `CLAUDE.local.json`) keys: `attribution` (commit/PR
footer), `prUrlTemplate` (PR-badge links), `includeGitInstructions: false`
(suppress Claude's built-in git briefing â€” this file's Git rules replace it;
already set in the kit).

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

Ignore TaskCreate / TaskUpdate / TaskList system-reminders unless the user
explicitly asked for an in-conversation task list. Progress is tracked via
GitHub issues, PRs, and `CHANGELOG.md`; in-conversation tasks are redundant.

## Skill routing

Match the task domain to the skill name â€” full descriptions live in each skill's
`description:` frontmatter.

Backends: `dotnet` skill Â· `java-kotlin` skill Â· `python` skill Â· `node` skill Â· `go` skill Â· `rust` skill  
Frontends: `angular` skill Â· `vue` skill Â· `svelte` skill Â· `react` skill Â· `mobile-rn` skill Â· `mobile-flutter` skill  
Data/Infra: `database` skill Â· `infrastructure` skill Â· `api-design` skill Â· `graphql` skill  
Quality: `architecture` skill Â· `testing` skill Â· `code-review` skill Â· `security` skill Â· `dependencies` skill Â· `github-workflow` skill  
Ops/X-cut: `observability` skill Â· `messaging` skill Â· `error-handling` skill Â· `monorepo` skill Â· `accessibility` skill Â· `i18n` skill Â· `ai-dev` skill Â· `performance` skill Â· `release-management` skill

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

## Engineering principles

- Prefer simple, explicit, consistent solutions over clever ones.
- Keep changes small and reviewable. One concern per PR.
- Add abstractions only when they remove real duplication or protect a real boundary.
- Respect layer boundaries and dependency direction. Avoid unrelated formatting changes.
- Do not add dependencies without justification. **MIT license only.** If it can
  be done in ~20 lines of native code, do not pull a package. See `dependencies` skill.
- Do not modify files outside the task scope.

## Proactive maintenance

You may notice out-of-scope improvements (outdated/vulnerable packages,
deprecated APIs, upgradable runtimes). Never fix them silently and never mix them
with the current task. Surface each explicitly (what, why, risk), wait for
approval, then apply with build + tests â€” one concern per PR, proposed
separately. Watch for: package updates/security patches, runtime LTS upgrades,
deprecated APIs with drop-in replacements, and transitive vulnerabilities
(`npm audit`, `pip-audit`, `cargo audit`, `dotnet list package --vulnerable`).

## Git rules

**Commit messages** â€” Conventional Commits: `<type>(<scope>): <subject>`.
- Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `ci`.
- Subject â‰¤ 72 chars, imperative mood (`add`, not `added`).
- Breaking changes: append `!` after type and add a `BREAKING CHANGE:` footer.
- One concern per commit. If the message needs `and`, split the commit.

**Push and history:**
- Never push directly to `main`, `master`, or `dev` â€” always via PR.
- Agent branches: `agent/<agent>/<model>/<type>/<area>` (dots OK, no `()` or spaces); work issue-first from an up-to-date `master`; English-only branch/issue/PR/commit text. See `docs/ai/WORKFLOW.md`.
- Do not rewrite history on shared branches.
- Do not run destructive Git commands without explicit approval.
- Do not delete user work or untracked files.

**Never commit:** `.env`, `*.local.json`, secrets, compiled binaries, `node_modules/`.

## Security rules

- Never print, expose, commit, or invent secrets.
- Do not read `.env`, secret files, or credentials unless explicitly approved.
- Do not weaken authentication, authorization, CORS, CSRF, CSP, or rate limits.

## Hardening and integration

Optional, opt-in `settings.json` keys (off by default): `autoMemoryEnabled` /
`autoMemoryDirectory` (persist cross-session facts), `apiKeyHelper` /
`awsCredentialExport` / `gcpAuthRefresh` (runtime credentials),
`disableSkillShellExecution` (block skill shell exec in locked-down CI).

## Definition of Done

- [ ] Requested behavior implemented.
- [ ] Change limited to task scope.
- [ ] Tests/build/lint run (or reason documented).
- [ ] New or changed behavior covered by tests, or an explicit note on why not and what to test manually.
- [ ] No unrelated files modified.
- [ ] Risks and assumptions stated.

## Final response format

1. **Summary** â€” what changed and why.
2. **Files changed** â€” with layer.
3. **Verification** â€” commands and results.
4. **Risks / assumptions**.
5. **Next step** â€” only if useful.
