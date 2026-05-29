# AGY.md

## Role

You are a software engineering agent working on this repository.

Your job: implement, refactor, review, test, and document changes while keeping
the codebase simple, maintainable, testable, and understandable.

The goal is not clever code. The goal is code a new developer can understand
and a team can safely evolve for years.

---

## How to run

Start Antigravity CLI in this project:

```bash
agy                              # interactive (default approval mode)
agy --approval-mode auto_edit    # auto-apply file edits, ask before shell commands
agy --approval-mode yolo         # fully autonomous — no prompts (use with care)
```

Approval modes:
- **default** — confirms every action before applying.
- **auto_edit** — applies file edits automatically; still asks before running commands.
- **yolo** — no confirmations; use only in sandboxed / throw-away environments.

Useful flags:
- `--model gemini-3.1-pro` — override the model for this session (GA as of April 2026).
- `--checkpointing` — enable automatic checkpointing so Antigravity can resume after an error or long pause.
- `--debug` — verbose output showing tool calls and model reasoning.

Antigravity CLI reads this file at startup. The kit configures `context.fileName`
as an array (`["AGENTS.md", "AGY.md", "CONTEXT.md"]`), so Antigravity loads
**all three files when present** and concatenates them in that order —
target projects that also use Codex get `AGENTS.md` merged in without
duplicating its content into `AGY.md`, and a project-level `CONTEXT.md`
(if the project chooses to add one) joins automatically. Files that don't
exist are silently skipped; you do not have to create the placeholders.
See [agycli.com/docs/cli/agy-md](https://agycli.com/docs/cli/agy-md/)
for the upstream multi-file behaviour.

Skills under `.agy/skills/<name>/SKILL.md`
are **Native Agent Skills**: Antigravity auto-discovers them at session start and
activates them based on their `description:` frontmatter. The routing table
below is the kit's policy for **deterministic activation** — it tells Antigravity
which skill applies for each task family so the choice doesn't depend on
description-matching heuristics. Run `/skills` (or `agy skills list`) at any
time to see which skills are discovered.

**References:**
- Source: [github.com/google-agy/agy-cli](https://github.com/google-agy/agy-cli)
- Docs: [google-agy.github.io/agy-cli/docs](https://google-agy.github.io/agy-cli/docs)
- Native Agent Skills: [agycli.com/docs/cli/creating-skills](https://agycli.com/docs/cli/creating-skills/)
- Using skills: [agycli.com/docs/cli/using-agent-skills](https://agycli.com/docs/cli/using-agent-skills/)
- GitHub Action: [github.com/google-github-actions/run-agy-cli](https://github.com/google-github-actions/run-agy-cli)

---

## Safety model — read this

**The kit ships a Antigravity `pre-bash-guard` hook in this release.** Wired
via `.agy/settings.json` as a `BeforeTool` hook matching
`run_shell_command`, it *mechanically blocks* force/mirror/delete push,
`git reset --hard/--keep`, ref deletion, `git switch --discard-changes`,
`git clean -f`, `rm -rf` on unsafe targets, and unapproved SQL `DROP`.
The denylist is byte-equivalent to the Claude / Codex `pre-bash-guard`
the kit has shipped since v1.16.5; the only difference is the wiring
(Antigravity's `hooksConfig` / `hooks` schema vs Claude's `settings.json`
hooks block vs Codex's `hooks.json`). When a command matches a rule
the hook prints the reason to stderr and exits 2 — Antigravity surfaces
that as a tool error and the turn continues.

Safety layers on Antigravity, in order:

1. **Approval mode.** `default` / `auto_edit` prompt the human before
   shell execution. `yolo` skips the prompt — but **the `BeforeTool`
   pre-bash-guard still fires** under it. `yolo` on Antigravity is now at
   the same risk level as Claude `--dangerously-skip-permissions` or
   Codex `approval_policy=never`: prompts are off, but the guard
   remains the second layer.
2. **`pre-bash-guard` (this release).** Denylist over the raw command
   string. Best-effort, not a sandbox — see the script header for the
   honest scope and limits, and ADR-008 for the design contract.
3. **Extension policies (`.agy/policies/`).** Auto-discovered by
   Antigravity at extension load time. The kit ships
   `destructive-git.toml` and `rm-rf.toml` covering the MCP-supply-
   chain layer (`[[rule]]` with `decision = "ask_user"` for MCP
   servers whose name advertises destructive behaviour). The hook
   above remains authoritative for native `run_shell_command` —
   policies cover the parallel risk of a third-party MCP tool
   performing the same operation outside the shell layer. See the
   policy file headers for the exact contract.
4. **`.agyignore`.** Keeps secrets and runtime files out of model
   context.
5. **CI.** The kit's GitHub Actions workflows reject merges that
   violate policy regardless of the local CLI.
6. **Router guidance below.** "Git rules" and "Security rules" remain
   self-enforced by the model as defense-in-depth.

Practical rules:

- The hook is a denylist, not a sandbox. Deliberate obfuscation
  (`base64 | eval`, here-strings, `bash -c "$(...)"`) can still slip
  through. Keep approval mode at `default` or `auto_edit` on any repo
  with real history/data; `yolo` is for sandboxed / throw-away
  checkouts.
- For anything touching git history, bulk deletion, or a database,
  prefer the prompt path over the hook — the hook is the cheap
  safety net, the human is the smart one.
- Format-on-save, notify-done, and session-summary hooks for Antigravity
  are not in this release; their `tool_input` / event payload schemas
  for `write_file` / `replace` / `SessionEnd` / `PreCompress` need to
  be confirmed against live Antigravity behaviour first. Tracked
  separately.

---

## Context strategy

Do not read every file. Read only what is needed, in this order:

1. This file.
2. The current GitHub issue or task description.
3. `docs/ai/PROJECT.md` when product or domain context is needed.
4. `docs/ai/ARCHITECTURE.md` when the task touches modules, boundaries, or design.
5. `docs/ai/COMMANDS.md` when build/test/lint commands are needed.
6. The relevant skill file (see routing below).
7. Source files directly related to the task.

Do not scan the entire repository unless the task explicitly requires it.

Recommend `/compress` proactively when you observe 4+ sequential reads, a large tool-output dump, ~20 turns, or an upcoming broad investigation — surface the recommendation before the heavy step, then wait for the user to type the command. See `docs/ai/CONTEXT_GOVERNANCE.md` for the 40/60/80% thresholds.

---

## Skill routing

Match the task domain to the skill name — load the file before editing. Antigravity auto-discovers skills via `description:` frontmatter; this list is the kit's deterministic override.

Backends: `.agy/skills/dotnet/SKILL.md` · `.agy/skills/java-kotlin/SKILL.md` · `.agy/skills/python/SKILL.md` · `.agy/skills/node/SKILL.md` · `.agy/skills/go/SKILL.md` · `.agy/skills/rust/SKILL.md`  
Frontends: `.agy/skills/angular/SKILL.md` · `.agy/skills/vue/SKILL.md` · `.agy/skills/svelte/SKILL.md` · `.agy/skills/react/SKILL.md` · `.agy/skills/mobile-rn/SKILL.md` · `.agy/skills/mobile-flutter/SKILL.md`  
Data/Infra: `.agy/skills/database/SKILL.md` · `.agy/skills/infrastructure/SKILL.md` · `.agy/skills/api-design/SKILL.md` · `.agy/skills/graphql/SKILL.md`  
Quality: `.agy/skills/architecture/SKILL.md` · `.agy/skills/testing/SKILL.md` · `.agy/skills/code-review/SKILL.md` · `.agy/skills/security/SKILL.md` · `.agy/skills/dependencies/SKILL.md` · `.agy/skills/github-workflow/SKILL.md`  
Ops/X-cut: `.agy/skills/observability/SKILL.md` · `.agy/skills/messaging/SKILL.md` · `.agy/skills/error-handling/SKILL.md` · `.agy/skills/monorepo/SKILL.md` · `.agy/skills/accessibility/SKILL.md` · `.agy/skills/i18n/SKILL.md` · `.agy/skills/ai-dev/SKILL.md` · `.agy/skills/performance/SKILL.md`

---

## Subagent routing

Antigravity CLI has native subagent support (April 2026+). Custom subagents live in
`.agy/agents/*.md` and are invoked by `@name`. This kit ships five:

| Situation | Use subagent |
|---|---|
| Affected area is unclear | `@codebase-investigator` |
| Change touches more than 5 files | `@code-reviewer` before final response |
| Test output is large | `@test-runner` |
| Task affects architecture | `@architect` |
| Security-sensitive change | `@security-reviewer` |

You can also let the main agent delegate automatically — it will pick the right
subagent based on the task description in each file's frontmatter.

**Reference:** [agycli.com/docs/core/subagents](https://agycli.com/docs/core/subagents/)

---

## Slash commands

The kit ships eleven workflow prompts as Antigravity custom commands in
`.agy/commands/*.toml`. Type `/` to autocomplete; pass the relevant input as
the argument (injected at `{{args}}`).

| Command | Use for | Argument |
|---|---|---|
| `/bug-fix` | Reproduce, root-cause, fix, regression test | issue number |
| `/code-review` | Triage-style review of a branch or diff | branch (optional) |
| `/daily-ticket` | Standard issue workflow | issue number |
| `/dependency-update` | Single-package update | pkg old new |
| `/feature-planning` | Plan-only, no code | issue number |
| `/on-call` | Live-incident playbook | symptoms |
| `/performance-audit` | Baseline → bottleneck → fix | what is slow |
| `/refactor` | Behaviour-preserving refactor | what to refactor |
| `/run-tests` | Run suite + report | (none) |
| `/security-audit` | Triage by severity | scope (optional) |
| `/tech-debt` | Triage-only debt scan | (none) |

A `agy-extension.json` scaffold is also provided in the kit (not installed by
default) for teams that want to distribute the kit as an installable Antigravity
extension via `agy extensions install`.

**Reference:** [Antigravity custom commands](https://google-agy.github.io/agy-cli/docs/cli/custom-commands.html)

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

## Engineering principles

- Prefer simple, explicit, consistent solutions over clever ones.
- Keep changes small and reviewable. One concern per PR.
- Do not over-engineer. Add abstractions only when they remove real duplication or protect a real boundary.
- Respect layer boundaries and dependency direction.
- Avoid unrelated formatting changes.
- Do not add dependencies without justification. **MIT license only.** Avoid library bloat — if it can be done in ~20 lines of native code, do not pull a package. See `.agy/skills/dependencies/SKILL.md`.
- Do not modify files outside the task scope.

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
