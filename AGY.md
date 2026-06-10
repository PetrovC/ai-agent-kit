# AGY.md

## Role

You are a software engineering agent on this repository: implement, refactor,
review, test, and document changes while keeping the codebase simple,
maintainable, and testable. The goal is not clever code — it is code a new
developer can understand and a team can safely evolve for years.

## How to run

```bash
agy                              # interactive (default approval mode)
agy --approval-mode auto_edit    # auto-apply file edits, ask before shell commands
agy --approval-mode yolo         # autonomous — no prompts (sandboxed/throw-away only)
```

Approval modes: **default** (confirm every action), **auto_edit** (auto-apply
edits, ask before commands), **yolo** (no confirmations). Useful flags:
`--model gemini-3.1-pro`, `--checkpointing` (resume after errors), `--debug`.

Antigravity reads this file at startup. The kit sets `context.fileName` to
`["AGENTS.md", "AGY.md", "CONTEXT.md"]`, so all present files load and concatenate
in that order — projects also using Codex get `AGENTS.md` merged without
duplicating it here. Skills under `.agy/skills/<name>/SKILL.md` are Native Agent
Skills auto-discovered by `description:`; the routing table below is the kit's
deterministic override. Run `/skills` to list them.
Reference: [github.com/google-agy/agy-cli](https://github.com/google-agy/agy-cli).

## Safety model — read this

The kit ships an Antigravity `pre-bash-guard` hook, wired via `.agy/settings.json`
as a `BeforeTool` hook matching `run_shell_command`. It mechanically blocks
force/mirror/delete push, `git reset --hard`/`--keep`, ref deletion,
`git switch --discard-changes`, `git clean -f`, `rm -rf` on unsafe targets, and
unapproved SQL `DROP` — printing the reason to stderr and exiting 2. The denylist
is byte-equivalent to the Claude/Codex guard; only the wiring differs.

Safety layers, in order:

1. **Approval mode** — `default`/`auto_edit` prompt before shell execution;
   `yolo` skips the prompt but the `BeforeTool` guard **still fires**.
2. **`pre-bash-guard`** — denylist over the raw command string. Best-effort, not
   a sandbox (see the script header and ADR-008).
3. **Extension policies (`.agy/policies/`)** — `destructive-git.toml` and
   `rm-rf.toml` cover the MCP-supply-chain layer (`decision = "ask_user"`).
4. **`.agyignore`** — keeps secrets and runtime files out of model context.
5. **CI** — workflows reject merges that violate policy regardless of the CLI.
6. **Router guidance below** — Git/Security rules, self-enforced.

Practical: the hook is a denylist, not a sandbox — deliberate obfuscation
(`base64 | eval`, here-strings, `bash -c "$(...)"`) can slip through, so keep
approval mode at `default`/`auto_edit` on any repo with real history/data (`yolo`
is for throw-away checkouts). For git-history, bulk-deletion, or database work,
prefer the prompt path over the hook.

## Context strategy

Do not read every file. Read only what is needed, in this order:

1. This file.
2. The current GitHub issue or task description.
3. `docs/ai/PROJECT.md` when product or domain context is needed.
4. `docs/ai/ARCHITECTURE.md` when the task touches modules, boundaries, or design.
5. `docs/ai/COMMANDS.md` when build/test/lint commands are needed.
6. The relevant skill file (see routing below).
7. Source files directly related to the task.

Do not scan the whole repository unless the task requires it. Recommend
`/compress` proactively at 4+ sequential reads, a large output dump, ~20 turns, or
an upcoming broad investigation — then wait. See `docs/ai/CONTEXT_GOVERNANCE.md`
for the 40/60/80% thresholds.

## Skill routing

Match the task domain to the skill name — load `.agy/skills/<name>/SKILL.md`
before editing. Antigravity auto-discovers skills via `description:`; this list is
the kit's deterministic override.

Backends: `.agy/skills/dotnet/SKILL.md` · `.agy/skills/java-kotlin/SKILL.md` · `.agy/skills/python/SKILL.md` · `.agy/skills/node/SKILL.md` · `.agy/skills/go/SKILL.md` · `.agy/skills/rust/SKILL.md`  
Frontends: `.agy/skills/angular/SKILL.md` · `.agy/skills/vue/SKILL.md` · `.agy/skills/svelte/SKILL.md` · `.agy/skills/react/SKILL.md` · `.agy/skills/mobile-rn/SKILL.md` · `.agy/skills/mobile-flutter/SKILL.md`  
Game: `.agy/skills/godot/SKILL.md`  
Data/Infra: `.agy/skills/database/SKILL.md` · `.agy/skills/infrastructure/SKILL.md` · `.agy/skills/api-design/SKILL.md` · `.agy/skills/graphql/SKILL.md`  
Quality: `.agy/skills/architecture/SKILL.md` · `.agy/skills/testing/SKILL.md` · `.agy/skills/code-review/SKILL.md` · `.agy/skills/security/SKILL.md` · `.agy/skills/dependencies/SKILL.md` · `.agy/skills/github-workflow/SKILL.md`  
Ops/X-cut: `.agy/skills/observability/SKILL.md` · `.agy/skills/messaging/SKILL.md` · `.agy/skills/error-handling/SKILL.md` · `.agy/skills/monorepo/SKILL.md` · `.agy/skills/accessibility/SKILL.md` · `.agy/skills/i18n/SKILL.md` · `.agy/skills/ai-dev/SKILL.md` · `.agy/skills/performance/SKILL.md` · `.agy/skills/release-management/SKILL.md`

## Subagent routing

Native subagents live in `.agy/agents/*.md`, invoked by `@name`. The kit ships five:

| Situation | Use subagent |
|---|---|
| Affected area is unclear | `@codebase-investigator` |
| Change touches more than 5 files | `@code-reviewer` before final response |
| Test output is large | `@test-runner` |
| Task affects architecture | `@architect` |
| Security-sensitive change | `@security-reviewer` |

The main agent may also delegate automatically based on each file's `description:`.

## Cross-agent delegation

Antigravity can delegate a single scoped task to Claude or Codex via the kit's
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

## Slash commands

Eleven workflow prompts as Antigravity custom commands in `.agy/commands/*.toml`
(type `/` to autocomplete; input injected at `{{args}}`): `/bug-fix`,
`/code-review`, `/daily-ticket`, `/dependency-update`, `/feature-planning`,
`/on-call`, `/performance-audit`, `/refactor`, `/run-tests`, `/security-audit`,
`/tech-debt`.

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

## Engineering principles

- Prefer simple, explicit, consistent solutions over clever ones.
- Keep changes small and reviewable. One concern per PR.
- Add abstractions only when they remove real duplication or protect a boundary.
- Respect layer boundaries and dependency direction; do not touch files or
  formatting outside the task scope.
- Do not add dependencies without justification. **MIT license only.** If it can
  be done in ~20 lines of native code, do not pull a package. See `.agy/skills/dependencies/SKILL.md`.

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
2. **Files changed** — with layer.
3. **Verification** — commands and results.
4. **Risks / assumptions**.
5. **Next step** — only if useful.
